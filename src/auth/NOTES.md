## Scope

`auth` is the general **compusib auth** toolchain for devcontainers. It is built
in slices:

| Slice | Status | What it provisions |
|---|---|---|
| **m2m-certs** | ✅ implemented | `jinja-template` + `ssh-jwt`, so the shared bash `gen-jwt` / `gen-cert` / `trust` mint machine-to-machine JWT credentials |
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
