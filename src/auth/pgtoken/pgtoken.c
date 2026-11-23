/* pgtoken.so: the loader of pgtoken's module, for libpq 18.
 *
 * libpq 19 loads the module (libpq-oauth.so) itself, when a server asks for a bearer token. libpq 18 cannot: a
 * flow of one's own gets in through the hook a program installs, and psql installs none. So this is preloaded
 * where libpq is 18 (the auth feature's ~/.bashrc.d/130_pgtoken.sh), and does there what libpq 19 does: it loads
 * the module by its name and calls the entry point of PostgreSQL 19's module ABI.
 *
 *   LD_PRELOAD=/usr/local/lib/pgtoken/pgtoken.so psql ...
 *
 * It is small on purpose and needs libc alone: it is in every program a shell starts. In a program that has no
 * libpq, or one older than 18, it does nothing. It replaces no function of any program, and exports none.
 * Where libpq is 19 it is not needed: it can be deleted, with the lines that preload it.
 *
 *   gcc -shared -fPIC -O2 -Wall -Wextra -fvisibility=hidden -o pgtoken.so pgtoken.c
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

#define MODULE "libpq-oauth.so"

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

typedef int (*AuthDataHook)(int type, void *conn, void *data);
typedef int (*StartFlow)(void *conn, BearerRequestV2 *request);

static AuthDataHook previous;

/* The module's entry point, as libpq 19 finds it: the file of that name on the linker's path. */
static StartFlow module(void)
{
    static StartFlow start;
    void *handle;

    if (!start && (handle = dlopen(MODULE, RTLD_NOW | RTLD_LOCAL)))
        start = (StartFlow) dlsym(handle, "pg_start_oauthbearer");
    return start;
}

/* libpq is done with the token: the module's own cleanup, of the request the module filled. */
static void done(void *conn, BearerRequest *request)
{
    BearerRequestV2 *filled = request->user;

    if (filled->v1.cleanup)
        filled->v1.cleanup(conn, &filled->v1);
    free(filled);
    request->token = NULL;
    request->user = NULL;
}

/* libpq 18 asks for a bearer token with the request of its day. The module gets PostgreSQL 19's, which begins
 * with the same members, and its answer is handed back. The issuer libpq 19 would add is not set: the module
 * does not use it.
 *
 * The module's token is handed on. Its failure ends the connection attempt. In two cases this steps aside and
 * libpq goes on to its own module, where one is installed: the module had nothing to sign with (it answers 1),
 * or it answered with a flow that wants to be called again, which only libpq itself can run. */
static int hook(int type, void *conn, void *data)
{
    BearerRequest *request = data;
    BearerRequestV2 *filled;
    StartFlow start;
    int answer, aside;

    if (type != 1 /* PQAUTHDATA_OAUTH_BEARER_TOKEN */ || !(start = module()))
        return previous ? previous(type, conn, data) : 0;
    if (!(filled = calloc(1, sizeof *filled)))
        return -1;
    filled->v1.openid_configuration = request->openid_configuration;
    filled->v1.scope = request->scope;
    answer = start(conn, filled);
    if (answer == 0 && filled->v1.token) {
        request->token = filled->v1.token;
        request->user = filled;
        request->cleanup = done;
        return 1;
    }
    aside = answer == 1 || (answer == 0 && filled->v1.async);
    if (filled->error)   /* the request of libpq 18 has no place for the reason: it is said here */
        fprintf(stderr, "pgtoken: %s\n", filled->error);
    if (filled->v1.cleanup)
        filled->v1.cleanup(conn, &filled->v1);
    free(filled);
    if (aside)
        return previous ? previous(type, conn, data) : 0;
    return -1;
}

__attribute__((constructor)) static void init(void)
{
    void (*set_hook)(AuthDataHook) = (void (*)(AuthDataHook)) dlsym(RTLD_DEFAULT, "PQsetAuthDataHook");
    AuthDataHook (*get_hook)(void) = (AuthDataHook (*)(void)) dlsym(RTLD_DEFAULT, "PQgetAuthDataHook");

    if (!set_hook || !get_hook)
        return;
    previous = get_hook();
    set_hook(hook);
}
