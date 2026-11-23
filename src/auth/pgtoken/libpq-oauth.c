/* libpq-oauth.so: pgtoken's module. A PostgreSQL client (psql) logs in over OAuth with a JWT that is given, or
 * with one minted for the ssh agent's key: no password, no browser.
 *
 * It is a module of PostgreSQL 19's public module ABI (src/interfaces/libpq-oauth/README: "As of v19, this module
 * ABI is public"). libpq 19 loads the file of this name itself, when a server asks for a bearer token and the
 * program has no flow of its own. libpq 18 cannot: there pgtoken.so is preloaded, and loads it the same way.
 * It takes the place of PostgreSQL's own module of this name, which sends the user to a browser.
 *
 * What a connection needs is libpq's own to say, and is the same on 18 and 19: oauth_issuer and oauth_client_id,
 * which a service names (PGSERVICE) or the connection itself. There are two ways in.
 *
 * A JWT that is given is handed on as it is. Nothing is minted, the mint is not loaded, and the connection's
 * client id is not used:
 *      PG_OAUTH_TOKEN        the token itself, or
 *      PG_OAUTH_TOKEN_FILE   a file that holds it
 *
 * Without one it is a developer's way in, and two signatures. The mint (pgtoken-oauth.so beside this file, or
 * PG_OAUTH_LIBRARY) signs an assert with the key in the ssh agent, which says who logs in. The client that asks
 * proves itself with a key of its own, a file (private_key_jwt): the host's. It has no secret. The assert is
 * exchanged at the token endpoint for the scope the server requires, and a token is given on the trust the
 * authorization server holds for the user's key.
 *      PG_OAUTH_CLIENT_KEY_FILE  the client's private key, a PEM file; not set: the client proves nothing
 *      PG_OAUTH_CLIENT_KEY_ID    the id the client publishes that key under; not set: the key file's name, a
 *                                space, the key's thumbprint
 *    The client's id is the connection's oauth_client_id. It differs per host, and libpq has no environment
 *    variable for it: where the connection names the word from_the_environment, it is
 *      PG_OAUTH_CLIENT_ID        the client's id, or
 *      PG_OAUTH_CLIENT_ID_FILE   a file whose first line is that id
 *      PG_OAUTH_SERVER    where the authorization server is reached; not set: at the connection's issuer
 *      PG_OAUTH_SUBJECT   who signs: the issuer the agent key's trust is registered under (else GIT_AUTHOR_EMAIL)
 *      PG_OAUTH_AUDIENCE  the audience asked for; not set: none
 *    A server written without a scheme is an https address. One without TLS is taken where libpq takes one
 *    (PGOAUTHDEBUG).
 *
 * With no JWT and no key to sign with (no ssh agent, or an empty one) there is nothing this module can do. It
 * then hands the request to PostgreSQL's own module, the libpq-oauth.so beside libpq itself, and says why on
 * standard error. Where that is not installed, the login fails with the reason. A refusal by the authorization
 * server is no reason to hand over: it is what psql shows.
 *
 * It needs libc alone: libpq's own functions are found in the program, at run time.
 *
 *   gcc -shared -fPIC -O2 -Wall -Wextra -fvisibility=hidden -Wl,-soname,libpq-oauth.so -o libpq-oauth.so libpq-oauth.c
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXPORT __attribute__((visibility("default")))
#define MINT_LIBRARY "pgtoken-oauth.so"
#define CLIENT_FROM_THE_ENVIRONMENT "from_the_environment"
#define NO_KEY "the ssh agent: "   /* how the mint begins when the agent, or a key in it, is not there */

typedef struct BearerRequest {   /* PGoauthBearerRequest of libpq-fe.h */
    const char *openid_configuration;
    const char *scope;
    void *async;
    void (*cleanup)(void *conn, struct BearerRequest *request);
    char *token;
    void *user;
} BearerRequest;

typedef struct {                 /* PGoauthBearerRequestV2: PostgreSQL 19 */
    BearerRequest v1;
    const char *issuer;
    const char *error;
} BearerRequestV2;

typedef struct {                 /* PQconninfoOption of libpq-fe.h */
    char *keyword, *envvar, *compiled, *val, *label, *dispchar;
    int dispsize;
} ConninfoOption;

typedef struct {                 /* pgtoken_request of pgtoken-oauth.so: every text is set, "" for none */
    const char *discovery, *server, *client_id, *client_key_file, *client_key_id, *scope, *audience, *subject;
    int allow_http;
} MintRequest;
typedef char *(*Mint)(const MintRequest *request, char **problem);
typedef int (*StartFlow)(void *conn, BearerRequestV2 *request);

EXPORT int pg_start_oauthbearer(void *conn, BearerRequestV2 *request);

/* Why there is no token, as a text of its own. A request's error points to it, and its cleanup frees it. */
static char *why(const char *format, ...)
{
    va_list args;
    char *text;

    va_start(args, format);
    if (vasprintf(&text, format, args) < 0)
        text = NULL;
    va_end(args);
    return text;
}

static const char *env(const char *name)
{
    const char *value = getenv(name);

    return value && *value ? value : NULL;
}

/* A token that is given: PG_OAUTH_TOKEN, or the content of the file PG_OAUTH_TOKEN_FILE names. NULL when none
 * is; with *error set when a file is named that gives none. */
static char *given_token(char **error)
{
    const char *value = env("PG_OAUTH_TOKEN"), *path;
    char *text;
    FILE *file;
    size_t n;

    if (value)
        return strdup(value);
    if (!(path = env("PG_OAUTH_TOKEN_FILE")))
        return NULL;
    if (!(file = fopen(path, "r")) || !(text = malloc(16384))) {
        *error = why("the token file %s cannot be read", path);
        if (file)
            fclose(file);
        return NULL;
    }
    n = fread(text, 1, 16383, file);
    fclose(file);
    while (n && strchr(" \t\r\n", text[n - 1]))
        n--;
    text[n] = 0;
    if (!n) {
        *error = why("the token file %s is empty", path);
        free(text);
        return NULL;
    }
    return text;
}

/* The request's cleanup: the token is wiped and freed, and so is the reason when there was none. */
static void forget(void *conn, BearerRequest *request)
{
    (void) conn;
    if (request->token) {
        memset(request->token, 0, strlen(request->token));
        free(request->token);
        request->token = NULL;
    }
    free(request->user);
    request->user = NULL;
}

/* libpq's own switch for an address without TLS, in a test: UNSAFE (all of it), or UNSAFE: and a list with http. */
static int http_allowed(void)
{
    const char *debug = getenv("PGOAUTHDEBUG");

    return debug && (!strcmp(debug, "UNSAFE") || (!strncmp(debug, "UNSAFE:", 7) && strstr(debug + 7, "http")));
}

/* The mint: pgtoken-oauth.so beside this file, or what PG_OAUTH_LIBRARY names. It is loaded when a token has to
 * be minted and not before: it starts Go's runtime in the program. */
static Mint load_mint(char **error)
{
    static Mint mint;
    char path[PATH_MAX + sizeof MINT_LIBRARY + 1], own[PATH_MAX], *slash;
    const char *library = env("PG_OAUTH_LIBRARY");
    Dl_info self;
    void *handle;

    if (mint)
        return mint;
    if (!library) {
        if (!dladdr((void *) load_mint, &self) || !self.dli_fname || !realpath(self.dli_fname, own)) {
            *error = why("where this module is, and the mint beside it, is not known");
            return NULL;
        }
        if ((slash = strrchr(own, '/')))
            *slash = 0;
        snprintf(path, sizeof path, "%s/%s", own, MINT_LIBRARY);
        library = path;
    }
    if (!(handle = dlopen(library, RTLD_NOW | RTLD_LOCAL)))
        *error = why("%s", dlerror());
    else if (!(mint = (Mint) dlsym(handle, "pgtoken_mint")))
        *error = why("%s has no pgtoken_mint", library);
    return mint;
}

/* The client's id where the connection leaves it to the environment: PG_OAUTH_CLIENT_ID, else the first line of
 * the file PG_OAUTH_CLIENT_ID_FILE names. Empty when neither gives one. */
static void client_from_the_environment(char *client, size_t size)
{
    const char *value = env("PG_OAUTH_CLIENT_ID"), *path;
    FILE *file;

    client[0] = 0;
    if (value) {
        snprintf(client, size, "%s", value);
    } else if ((path = env("PG_OAUTH_CLIENT_ID_FILE")) && (file = fopen(path, "r"))) {
        if (!fgets(client, size, file))
            client[0] = 0;
        fclose(file);
        client[strcspn(client, " \t\r\n")] = 0;
    }
}

/* A token for the connection's client, minted for the key in the ssh agent. NULL with *error set when none is. */
static char *minted_token(void *conn, const BearerRequestV2 *request, char **error)
{
    ConninfoOption *(*conninfo)(void *) = (ConninfoOption *(*)(void *)) dlsym(RTLD_DEFAULT, "PQconninfo");
    void (*release)(ConninfoOption *) = (void (*)(ConninfoOption *)) dlsym(RTLD_DEFAULT, "PQconninfoFree");
    ConninfoOption *options, *o;
    const char *subject, *server = env("PG_OAUTH_SERVER"), *audience = env("PG_OAUTH_AUDIENCE");
    const char *key_file = env("PG_OAUTH_CLIENT_KEY_FILE"), *key_id = env("PG_OAUTH_CLIENT_KEY_ID");
    char client[256] = "", server_address[1024] = "", *token;
    MintRequest wanted;
    Mint mint;

    if (conninfo && release && (options = conninfo(conn))) {
        for (o = options; o->keyword; o++)
            if (!strcmp(o->keyword, "oauth_client_id") && o->val)
                snprintf(client, sizeof client, "%s", o->val);
        release(options);
    }
    if (!strcmp(client, CLIENT_FROM_THE_ENVIRONMENT)) {
        client_from_the_environment(client, sizeof client);
        if (!client[0]) {
            *error = why("the connection leaves the client to the environment, and neither PG_OAUTH_CLIENT_ID nor "
                         "the file PG_OAUTH_CLIENT_ID_FILE names gives one");
            return NULL;
        }
    }
    if (!request->v1.openid_configuration || !client[0]) {
        *error = why("the connection names no issuer or no client id");
        return NULL;
    }
    if (!(subject = env("PG_OAUTH_SUBJECT")) && !(subject = env("GIT_AUTHOR_EMAIL"))) {
        *error = why("who signs is not known: PG_OAUTH_SUBJECT is the issuer the key's trust is registered under");
        return NULL;
    }
    if (!(mint = load_mint(error)))
        return NULL;
    if (server)   /* as it is written, or https:// before a bare host */
        snprintf(server_address, sizeof server_address, "%s%s", strstr(server, "://") ? "" : "https://", server);
    wanted.discovery = request->v1.openid_configuration;
    wanted.server = server_address;
    wanted.client_id = client;
    wanted.client_key_file = key_file ? key_file : "";
    wanted.client_key_id = key_id ? key_id : "";
    wanted.scope = request->v1.scope ? request->v1.scope : "";
    wanted.audience = audience ? audience : "";
    wanted.subject = subject;
    wanted.allow_http = http_allowed();
    token = mint(&wanted, error);   /* the mint's reason is a text of its own too */
    return token;
}

/* PostgreSQL's own module of this name: the one beside libpq itself. NULL where its package is not installed,
 * and where libpq is an 18, whose own module has another name and is libpq's to load. */
static StartFlow postgresql_own(void)
{
    static StartFlow start;
    static int tried;
    void *of_libpq = dlsym(RTLD_DEFAULT, "PQconninfo"), *handle;
    void (*init)(void *);
    char path[PATH_MAX + sizeof "libpq-oauth.so"], *slash;
    Dl_info libpq;

    if (tried)
        return start;
    tried = 1;
    if (!of_libpq || !dladdr(of_libpq, &libpq) || !libpq.dli_fname || strlen(libpq.dli_fname) >= PATH_MAX)
        return NULL;
    strcpy(path, libpq.dli_fname);
    if (!(slash = strrchr(path, '/')))
        return NULL;
    strcpy(slash + 1, "libpq-oauth.so");
    if (!(handle = dlopen(path, RTLD_NOW | RTLD_LOCAL)))
        return NULL;
    /* What libpq does before it runs that module: it would hand its translations on, which is not this
     * module's to do. Without them the messages are as they are written. */
    if ((init = (void (*)(void *)) dlsym(handle, "libpq_oauth_init")))
        init(NULL);
    start = (StartFlow) dlsym(handle, "pg_start_oauthbearer");
    if (start == pg_start_oauthbearer)   /* this module itself, found there */
        start = NULL;
    return start;
}

/* The entry point of PostgreSQL 19's module ABI. libpq 19 calls it; on 18, pgtoken.so does. It answers zero
 * with the token set; -1 with the reason; and 1 with the reason when there was nothing to sign with and no
 * other module to hand over to, on which pgtoken.so leaves libpq 18 to its own. */
EXPORT int pg_start_oauthbearer(void *conn, BearerRequestV2 *request)
{
    char *error = NULL, *token = given_token(&error);
    int nothing_to_sign_with;
    StartFlow other;

    if (!token && !error)
        token = minted_token(conn, request, &error);
    nothing_to_sign_with = !token && error && !strncmp(error, NO_KEY, sizeof NO_KEY - 1);
    if (nothing_to_sign_with && (other = postgresql_own())) {
        fprintf(stderr, "pgtoken: %s\n", error);
        free(error);
        return other(conn, request);
    }
    request->v1.token = token;
    request->v1.user = token ? NULL : error;
    request->v1.cleanup = forget;
    if (token)
        return 0;
    request->error = error ? error : "no token";
    return nothing_to_sign_with ? 1 : -1;
}
