## What it does

On every container start (`postStartCommand`), `ensure-compusib-marketplace`
writes `~/.claude/settings.json` with `jq` so Claude installs the compusib
plugins itself — no `claude` binary, no session hook:

- **`extraKnownMarketplaces.compusib`** — the marketplace source.
- **`enabledPlugins`** — every plugin in `claudePlugins` (default `base-stack@compusib`).

The source follows whether a local checkout is mounted:

- **`pluginMarketplaceLocalOverride`** (default `/workspace/compusib/ai`) holds a
  `.claude-plugin/marketplace.json` → a **local `directory`** source.
- otherwise → the **online `git`** source (**`pluginMarketplace`**).

It is re-evaluated each start; flipping between local and online re-resolves cleanly.

On attach (`postAttachCommand`), `bootstrap-claude-sync` syncs `~/.claude` to
Backblaze B2 via `rcloneops` (disable with `bootstrapClaudeSync: false`).

## Requirements

- **Data sync** needs the **`bashrc`** feature (a `dependsOn`, installed
  automatically) plus the compusib **bash repo mounted** at `compusibBashRepoRoot`
  (default `/workspace/compusib/bash`) — that is what puts `rcloneops` on `PATH`.
  Without it, sync is skipped.
- **B2 credentials** in the container env (forward from the host as **secrets** —
  never commit them): `DEVCONTAINERS_B2_ACCOUNT`, `DEVCONTAINERS_B2_KEY`,
  `DEVCONTAINERS_B2_BUCKET`, and an email via `DEVCONTAINER_USER_EMAIL` (falls
  back to `GIT_AUTHOR_EMAIL`). Missing credentials → sync is skipped; the attach
  never fails.
- **System packages** `rclone` (**>= 1.66**), `jq`, `gh`. Missing ones are
  installed at build time (with a warning), unless `skipInstallSystemPackages`.

```jsonc
"containerEnv": {
    "DEVCONTAINERS_B2_ACCOUNT": "${localEnv:DEVCONTAINERS_B2_ACCOUNT}",
    "DEVCONTAINERS_B2_KEY": "${localEnv:DEVCONTAINERS_B2_KEY}",
    "DEVCONTAINERS_B2_BUCKET": "${localEnv:DEVCONTAINERS_B2_BUCKET}"
}
```

## Recommendations

- **For marketplace/plugin development**, mount your `compusib/ai` checkout at
  `/workspace/compusib/ai` (the `pluginMarketplaceLocalOverride` default): the
  feature points Claude at your working tree instead of the published git
  marketplace, so edits show up on the next start with no push/pull.

- **Bake the system packages into your image** so they aren't reinstalled on
  every rebuild, then set `skipInstallSystemPackages: true`. `jq` is in Debian's
  repos; `rclone` must be **>= 1.66** (newer than apt's), so use the official
  script; `gh` needs GitHub's apt repo:

  ```dockerfile
  RUN apt-get update \
   && apt-get install -y --no-install-recommends jq curl unzip ca-certificates \
   && curl -fsSL https://rclone.org/install.sh | bash \
   && install -m 0755 -d /etc/apt/keyrings \
   && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/gh.gpg \
   && chmod go+r /etc/apt/keyrings/gh.gpg \
   && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/gh.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/gh.list \
   && apt-get update && apt-get install -y --no-install-recommends gh \
   && rm -rf /var/lib/apt/lists/*
  ```
