
# Claude (claude)

Installs the private compusib.settings-bridge VS Code extension (from a local working tree when available, otherwise cloned from git at runtime) and provisions Claude data sync (~/.claude to Backblaze B2 via rcloneops) on attach.

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/claude:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installSettingsBridge | Install the compusib.settings-bridge VS Code extension. | boolean | true |
| skipInstallSystemPackages | Skip the fallback installation of system packages (rclone, jq, gh) the feature relies on. Set to true when those packages are baked into your devcontainer's Dockerfile so the feature does not try to install them at build time. | boolean | false |
| settingsBridgeRepoPath | Local working tree of settingsBridgeRepo, if it is already checked out into the container (e.g. bind-mounted for extension development). When it contains a *.vsix at settingsBridgeVsixDir it is used as the source, preferred over cloning. Set to empty to always download. | string | /workspace/compusib/ai |
| settingsBridgeRepo | Git URL of the repo to clone the settings-bridge .vsix from when no local working tree (settingsBridgeRepoPath) is present. SSH form by default (relies on SSH-agent forwarding); use the https URL if your container has an HTTPS credential helper instead. | string | git@github.com:compusib/ai.git |
| settingsBridgeRef | Git ref (branch/tag) to fetch when downloading the .vsix. | string | main |
| settingsBridgeVsixDir | Directory holding the built *.vsix, relative to the repo root. Applies identically to settingsBridgeRepoPath and to a fresh clone of settingsBridgeRepo. | string | vscode/settings-bridge/dist |
| extensionId | Extension id (publisher.name) used for the already-installed idempotency guard. | string | compusib.settings-bridge |
| claudePlugins | Space-separated Claude Code plugins (each <name>@<marketplace>) every container using this feature should have installed from pluginMarketplace. Defaults to the compusib baseline; override per devcontainer, or set to empty to install none. | string | base-stack@compusib |
| pluginMarketplace | Online (git) source for the compusib Claude Code plugin marketplace. Written declaratively into ~/.claude/settings.json (extraKnownMarketplaces) at postStart by ensure-compusib-marketplace; used unless pluginMarketplaceLocalOverride names a mounted local checkout. SSH form by default (relies on SSH-agent forwarding). | string | git@github.com:compusib/ai.git |
| pluginMarketplaceLocalOverride | Directory that, when present and containing .claude-plugin/marketplace.json, makes the feature register the compusib marketplace as a local 'directory' source pointing at it (instead of the online pluginMarketplace git source). Re-evaluated on every container start; set to empty to always use the online source. | string | /workspace/compusib/ai |
| bootstrapClaudeSync | Run 'rcloneops claude-bootstrap' on attach to provision Claude data sync for ~/.claude (bisync baseline + session hooks against Backblaze B2). Requires rcloneops on PATH (from the bashrc feature) and the DEVCONTAINERS_B2_* credentials in the env; cleanly no-ops otherwise. Set false to disable entirely. | boolean | true |

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


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/claude/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
