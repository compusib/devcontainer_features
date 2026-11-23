/* The validator of gate L's server. It verifies nothing and is never shipped: it lets every bearer in, and says
 * as who. That is the payload segment of the token, as it is written, so that the gate can read whose token the
 * server got without the token being written anywhere. */
#include "postgres.h"
#include "fmgr.h"
#include "libpq/oauth.h"

PG_MODULE_MAGIC;

static bool
validate(const ValidatorModuleState *state, const char *token, const char *role, ValidatorModuleResult *result)
{
    const char *first = strchr(token, '.'), *second = first ? strchr(first + 1, '.') : NULL;

    result->authorized = true;
    result->authn_id = second ? pnstrdup(first + 1, second - first - 1) : pstrdup("no-payload");
    return true;
}

static const OAuthValidatorCallbacks callbacks = {PG_OAUTH_VALIDATOR_MAGIC, .validate_cb = validate};

const OAuthValidatorCallbacks *
_PG_oauth_validator_module_init(void)
{
    return &callbacks;
}
