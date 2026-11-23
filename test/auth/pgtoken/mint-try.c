/* mint-try: calls pgtoken_mint of a library and prints the token, or the problem on standard error.
 *   mint-try <pgtoken-oauth.so> <name=value>...
 * names: discovery server client_id scope audience subject allow_http
 * A name given twice has its last value.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *discovery, *server, *client_id, *scope, *audience, *subject;
    int allow_http;
} Request;
typedef char *(*Mint)(const Request *, char **);

int main(int argc, char **argv)
{
    Request r = {"", "", "", "", "", "", 0};
    const char *names[] = {"discovery", "server", "client_id", "scope", "audience", "subject"};
    const char **fields[] = {&r.discovery, &r.server, &r.client_id, &r.scope, &r.audience, &r.subject};
    char *problem = NULL, *token, *equals;
    void *library;
    Mint mint;
    int i, j;

    if (argc < 2 || !(library = dlopen(argv[1], RTLD_NOW)) || !(mint = (Mint) dlsym(library, "pgtoken_mint"))) {
        fprintf(stderr, "mint-try: %s\n", argc < 2 ? "a library" : dlerror());
        return 2;
    }
    for (i = 2; i < argc; i++) {
        if (!(equals = strchr(argv[i], '=')))
            return 2;
        *equals = 0;
        if (!strcmp(argv[i], "allow_http"))
            r.allow_http = atoi(equals + 1);
        for (j = 0; j < 6; j++)
            if (!strcmp(argv[i], names[j]))
                *fields[j] = equals + 1;
    }
    if (!(token = mint(&r, &problem))) {
        fprintf(stderr, "%s\n", problem ? problem : "no token");
        return 1;
    }
    puts(token);
    return 0;
}
