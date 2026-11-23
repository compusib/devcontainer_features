
# auth (auth)

compusib auth toolchain for devcontainers. Implemented slices — m2m-certs: provisions jinja-template (compy wheel) and ssh-jwt (go.ptx.dk/ssh-jwt) via mise so the shared bash gen-jwt/gen-cert/trust mint machine-to-machine JWT credentials. pgtoken: a PostgreSQL client on libpq 18 or newer (psql) logs in over OAuth with a JWT that is given or with the ssh agent's key, no password and no browser. It installs a module of PostgreSQL 19's public libpq-oauth ABI, which libpq 19 loads by itself, and a loader that the remote user's ~/.bashrc.d preloads where libpq is 18. The connection's service names the issuer and the client; the feature sets no PG_OAUTH_* variable and installs no PostgreSQL client. Browser auth flows are a planned future slice. Requires a preinstalled mise; it does not install mise.

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/auth:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| compyRepoPath | Path to the compusib/compy checkout. The jinja-template package is installed from <path>/apps/jinja-template into the mise-managed Python. | string | /workspace/compusib/compy |
| sshJwtVersion | Version of go.ptx.dk/ssh-jwt to build via mise's Go backend (go install go.ptx.dk/ssh-jwt/cmd/ssh-jwt@<version>). Accepts a tag (e.g. 'v0.0.6') or 'latest' (resolves to the newest published tag). | string | latest |
| pythonVersion | Fallback Python to declare via mise (e.g. '3.13') ONLY if no mise Python is already active. Empty (default) never overrides an existing pin. | string | - |
| keepGoToolchain | Keep the Go mise tool after building ssh-jwt. Set false to run 'mise uninstall go' afterward (ssh-jwt keeps working; rebuilding it later needs Go again). | boolean | true |

## Scope

`auth` is the general **compusib auth** toolchain for devcontainers. It is built
in slices:

| Slice | Status | What it provisions |
|---|---|---|
| **m2m-certs** | ✅ implemented | `jinja-template` + `ssh-jwt`, so the shared bash `gen-jwt` / `gen-cert` / `trust` mint machine-to-machine JWT credentials |
| **pgtoken** | ✅ implemented | psql logs in to a PostgreSQL server over OAuth, with a JWT that is given or with the ssh agent's key: no password, no browser. See [pgtoken](#pgtoken-psql-logs-in-over-oauth) |
| browser auth flows | 🔜 planned | interactive / browser login provisioning (not yet implemented) |

## How it works (m2m-certs)

The signing logic already lives in the **bash** repo
(`/workspace/compusib/bash/bin/{gen-jwt,gen-cert,trust}`) and reaches the
container via the shared `/workspace` mount + the **bashrc** feature's PATH. Those
scripts need two tools this feature provides:

1. **`jinja-template`** — renders a Jinja2 *claim* template into a JSON payload.
   Installed from the compy wheel at `<compyRepoPath>/apps/jinja-template` into the
   mise-managed Python.
2. **`ssh-jwt`** — the [`go.ptx.dk/ssh-jwt`](https://github.com/ptxmac/ssh-jwt)
   signer. Built from source via mise's **Go backend**
   (`go install go.ptx.dk/ssh-jwt/cmd/ssh-jwt@<sshJwtVersion>`).

Both are installed as **mise tools** (exposed on PATH via mise shims) by the
`provision-auth` helper, which runs at **`onCreateCommand`** (as the remote user,
when `/workspace` and the user-level mise are available). `install.sh` only stages
the helper and the resolved options at build time.

Pipeline: `jinja-template <claim-template> | ssh-jwt signjson` → signed `.jwt`.

## Prerequisites

- **mise must be preinstalled** in the image (e.g. via the Dockerfile). This
  feature does **not** install mise — it yields to the preinstalled one and to any
  existing tool pins (it will not re-pin an already-active Python). A dedicated
  mise-installer feature is planned.
- A Python is needed for `jinja-template`. If the image already pins one via mise
  (recommended), the feature uses it; otherwise set the `pythonVersion` option.
- The **bashrc** feature (a hard dependency) and checkouts of `compy` and `bash`
  under `/workspace`.

## Usage

With the feature applied and the bashrc PATH active:

```bash
gen-jwt rabbitmq            # render a claim template + sign → a .jwt
jinja-template <tmpl> -     # render claims to stdout
ssh-jwt --help             # the signer
```

## Re-running

`provision-auth` is idempotent — re-run it any time (e.g. after pulling a new
`jinja-template` or bumping `sshJwtVersion`):

```bash
provision-auth
```

## pgtoken: psql logs in over OAuth

A PostgreSQL client (psql, pg_dump, …) logs in to a server that takes OAuth logins. There are two ways in.

| Way in | Who | What happens |
|---|---|---|
| A JWT is given | a machine, or a developer who brings one in from outside the container | it is handed on as it is. Nothing is minted |
| The ssh agent's key | a developer | two signatures. An assert signed by the agent's key says who logs in. The client that asks proves itself with a key of its own, the host's (`private_key_jwt`); it has no secret. The assert is exchanged at the authorization server (Hydra) for a token, and whether one is given rests on the trust registered there for the developer's key |

Every other way of logging in (a password, a certificate, …) works as before: pgtoken is asked only when a
server asks for a bearer token.

### What the feature installs, and how it is turned on

Three files, in `/usr/local/lib/pgtoken`. The feature turns them on by itself: there is no option for it.

| File | Is |
|---|---|
| `libpq-oauth.so` | the module, on PostgreSQL 19's public module ABI. It hands a given JWT on, or has one minted |
| `pgtoken-oauth.so` | the mint: the signature by the agent's key, and the exchange. Loaded when a token has to be minted, and not before |
| `pgtoken.so` | the loader, for libpq 18 |

| The container's libpq | What happens |
|---|---|
| 19 or newer | libpq loads the module itself, by its name: the feature puts the directory first on the linker's path. Nothing is preloaded and no variable is set |
| 18 | libpq cannot load a module of one's own. `~/.bashrc.d/130_pgtoken.sh` puts the loader into `LD_PRELOAD` in the user's shells, and the loader loads the module the way libpq 19 does |
| older, or none | nothing: there is no OAuth in that libpq |

The feature installs **no PostgreSQL client**: it comes from elsewhere. A PostgreSQL 18 client installed from
PGDG runs on libpq 19 today, so the first row is the usual one. When no container has libpq 18 any more, the
loader and the file in `~/.bashrc.d` can be deleted and the rest stays as it is.

A libpq 18 that is not the system's (`/usr/lib/<triplet>/libpq.so.5`), one that mise built for instance, is not
recognised. Its user sets `LD_PRELOAD=/usr/local/lib/pgtoken/pgtoken.so`.

### What a connection has to name

libpq wants two settings before it asks anybody for a token, and has no environment variable for either:
`oauth_issuer` and `oauth_client_id`. A connection names them itself, or a service does:

```ini
# ~/.pg_service.conf
[oauth]
host=<the server>
dbname=<the database>
oauth_issuer=https://auth.compusib.ro
oauth_client_id=psql
```

```bash
export PGSERVICE=oauth      # or: psql service=oauth
psql
```

What a connection string writes wins over the service, and the service over the `PG*` variables: that is
libpq's own order, and pgtoken takes the client id of the connection as libpq ends up with it.

**The client differs per host**, and a service file that every host shares cannot name it. So the service names
the word `from_the_environment`, and the client is then `PG_OAUTH_CLIENT_ID`, else the first line of the file
`PG_OAUTH_CLIENT_ID_FILE` names:

```ini
oauth_client_id=from_the_environment
```

Any other id a connection names is used as it is written, so a connection string still decides.

With a JWT that is given the client id is not used. libpq still wants one named: any word does, such as
`oauth_client_id=jwt_instead_of_client_id`.

### The variables

None is set by the feature, and none has an option: a container sets what it needs. What is not set has the
module's own behaviour.

| Variable | Is | Not set |
|---|---|---|
| `PG_OAUTH_TOKEN` | a JWT that is given | the file below |
| `PG_OAUTH_TOKEN_FILE` | a file that holds it | the developer's way: a token is minted |
| `PG_OAUTH_CLIENT_ID` | the client's id, where the connection names `from_the_environment` | the file below |
| `PG_OAUTH_CLIENT_ID_FILE` | a file whose first line is that id | the login fails: the connection left the client to the environment |
| `PG_OAUTH_CLIENT_KEY_FILE` | the client's private key, a PEM file (RSA): the client proves itself with it | the client proves nothing: a public client |
| `PG_OAUTH_CLIENT_KEY_ID` | the id the client publishes that key under | the key file's name, a space, the key's RFC 7638 thumbprint: as the gateway names it |
| `PG_OAUTH_SERVER` | where the authorization server is reached | at the connection's `oauth_issuer` |
| `PG_OAUTH_SUBJECT` | who signs: the issuer the agent key's trust is registered under | `GIT_AUTHOR_EMAIL` |
| `PG_OAUTH_AUDIENCE` | the audience asked for | none is asked for |
| `PG_OAUTH_LIBRARY` | the path of the mint, `pgtoken-oauth.so` | beside the module |

A variable that is set and empty counts as not set. The key file is read when a token is minted and at no
other time. There is no client secret anywhere.

**A JWT from outside the container.** `PG_OAUTH_TOKEN` is looked at wherever the client runs, so a token the
host has can be brought in through `devcontainer.json`:

```jsonc
"remoteEnv": { "PG_OAUTH_TOKEN": "${localEnv:PG_OAUTH_TOKEN}" }
```

`remoteEnv` is read when the editor attaches, so a new token arrives with the next attach. `containerEnv` is
fixed when the container is created. Where the host has no such variable the value is empty, and a token is
minted as if it were not set.

**Per directory.** mise sets any of them, and `PGSERVICE` with them, for one repo:

```toml
# mise.toml
[env]
PGSERVICE = "oauth"
PG_OAUTH_SUBJECT = "dev@compusib.ro"
PG_OAUTH_CLIENT_ID = "<host>_private_key_jwt"
PG_OAUTH_AUDIENCE = "<the audience asked for>"
PG_OAUTH_CLIENT_KEY_FILE = "/data/certs/oauth2/<host>"
```

### When there is nothing to sign with

With no JWT and no key to sign with (no ssh agent, or an empty one) pgtoken hands the login to PostgreSQL's own
`libpq-oauth`, which sends the user to a browser, and says why in one line. That happens only where that
package is installed (it is not, by default); elsewhere the login fails with the reason. pgtoken's module is the
one that is found first in either case. A refusal by the authorization server (no trust for the key, a subject
it does not know) is never replaced by the browser: psql shows it.

### When a login fails

- psql's message carries the reason on libpq 19 (`user-defined OAuth flow failed: …`). On libpq 18 the loader
  says it on standard error (`pgtoken: …`).
- `server requires OAuth authentication, but oauth_issuer and oauth_client_id are not both set`: no service is
  named, or it lacks one of the two.
- `invalid_client` from the authorization server: the client is not known there, or it has to prove itself and
  `PG_OAUTH_CLIENT_KEY_FILE` is not set or names another key than the one it published.
- `no OAuth flows are available`: libpq found no module. On libpq 19, `PGOAUTHDEBUG=plugin-errors` says why.
  On libpq 18 the loader is not in `LD_PRELOAD`: the shell has not read `~/.bashrc.d`.

### Building it (this repo)

The libraries are not in git. `make -C src/auth/pgtoken dist` builds them for `linux/amd64` and `linux/arm64`
in an image of Debian 12 (the older libc they have to run on), with the go `mise.toml` pins; CI does that before
it tests and before it publishes. `make -C src/auth/pgtoken` builds for this machine, and
`bash test/auth/pgtoken/gates.sh` tries the result: the loader in programs that are no PostgreSQL client (I),
the mint against a throwaway Hydra (M), and logins on libpq 18 and 19 at a throwaway PostgreSQL server (L).


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/auth/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
