
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
| skipInstallSystemPackages | Skip the fallback installation of system packages (rclone, gh) the feature relies on. Set to true when those packages are baked into your devcontainer's Dockerfile so the feature does not try to install them at build time. | boolean | false |
| settingsBridgeRepoPath | Local working tree of settingsBridgeRepo, if it is already checked out into the container (e.g. bind-mounted for extension development). When it contains a *.vsix at settingsBridgeVsixDir it is used as the source, preferred over cloning. Set to empty to always download. | string | /workspace/compusib/ai |
| settingsBridgeRepo | Git URL of the repo to clone the settings-bridge .vsix from when no local working tree (settingsBridgeRepoPath) is present. SSH form by default (relies on SSH-agent forwarding); use the https URL if your container has an HTTPS credential helper instead. | string | git@github.com:compusib/ai.git |
| settingsBridgeRef | Git ref (branch/tag) to fetch when downloading the .vsix. | string | main |
| settingsBridgeVsixDir | Directory holding the built *.vsix, relative to the repo root. Applies identically to settingsBridgeRepoPath and to a fresh clone of settingsBridgeRepo. | string | vscode/settings-bridge/dist |
| extensionId | Extension id (publisher.name) used for the already-installed idempotency guard. | string | compusib.settings-bridge |
| claudePlugins | Space-separated Claude Code plugins (each <name>@<marketplace>) every container using this feature should have installed from pluginMarketplace. Installed at each Claude session launch by claude-process-wrapper (set as claudeCode.claudeProcessWrapper) via 'claude plugin install', which also pulls each plugin's full dependency closure. Defaults to the compusib baseline; override per devcontainer, or set to empty to install none. | string | base-stack@compusib |
| defaultPluginConfigs | Before installing each plugin, seed its userConfig defaults (declared in the plugin manifest) into ~/.claude/settings.json, using the bash repo's 'manifest-to-default-user-config' (resolved via BASH_REPO_ROOT). Best-effort and idempotent: fill-only (never overwrites a value you have already set), skips plugins that declare no defaults, and silently no-ops when the helper or a manifest is unavailable. Set false to skip default seeding. | boolean | true |
| pluginMarketplace | Online (git) source for the compusib Claude Code plugin marketplace. Registered at session launch by claude-process-wrapper via 'claude plugin marketplace add'; used unless pluginMarketplaceLocalOverride names a mounted local checkout. SSH form by default (relies on SSH-agent forwarding). | string | git@github.com:compusib/ai.git |
| pluginMarketplaceLocalOverride | Directory that, when present and containing .claude-plugin/marketplace.json, makes the feature register the compusib marketplace as a local 'directory' source pointing at it (instead of the online pluginMarketplace git source). Re-evaluated on every container start; set to empty to always use the online source. | string | /workspace/compusib/ai |
| bootstrapClaudeSync | Run 'rcloneops claude-bootstrap' on attach to establish the ~/.claude bisync baseline against Backblaze B2. (The session-sync hooks ship in the rclone Claude Code plugin, enabled declaratively via claudePlugins — not installed here.) Requires rcloneops on PATH (from the bashrc feature) and the DEVCONTAINERS_B2_* credentials in the env; cleanly no-ops otherwise. Set false to disable entirely. | boolean | true |

## Customizations

### VS Code Extensions

- `/home/node/.cache/claude-feature/settings-bridge/compusib.settings-bridge.vsix`

## What it does

The feature sets `claudeCode.claudeProcessWrapper` (via
`customizations.vscode.settings`) to `claude-process-wrapper`. The extension
spawns it with its bundled `claude` as `$1`, just before a session — the only
point before plugin hooks load that has `claude` in hand. The wrapper:

1. writes `$1`'s dir to `~/.bashrc.d/107_claude_bin_path.sh` (shells resolve
   `claude` without globbing);
2. runs `ensure-marketplace-recursively-installed` with that binary:
   `claude plugin marketplace add <source>` + `claude plugin install` of
   `claudePlugins` (no `jq`);
3. `exec`s the session.

Install finishes before `exec`, so hooks load in that session. A sentinel
(`~/.claude/.plugins-ensured`, keyed on plugins+source+version) skips the work on
later launches. Source: `pluginMarketplaceLocalOverride` (a mounted checkout
holding `.claude-plugin/marketplace.json`) → `directory`, else `pluginMarketplace` git.

> `claude plugin install` resolves a plugin's direct deps, but a dep it
> *auto-installs* gets only its **first** dep resolved (2.1.143–2.1.177,
> anthropics/claude-code#68449). So the script re-installs each installed plugin
> explicitly, looping until none are new — pulling the full closure
> (`base-stack → base → rclone`).

On attach (`postAttachCommand`), `bootstrap-claude-sync` establishes the
`~/.claude` ↔ Backblaze B2 bisync baseline via `rcloneops` (disable with
`bootstrapClaudeSync: false`). The session-sync hooks themselves ship in the
`rclone` plugin (a dependency pulled in above), not from this feature.

## Requirements

- **Mount the compusib bash repo** at `compusibBashRepoRoot` (default
  `/workspace/compusib/bash`) and keep the **`bashrc`** feature (a `dependsOn`,
  auto-installed). They put `rcloneops` on `PATH`; data sync uses it, and is
  skipped without it.
- **Set the B2 credentials** in the container env, as secrets (never commit):
  `DEVCONTAINERS_B2_ACCOUNT`, `DEVCONTAINERS_B2_KEY`, `DEVCONTAINERS_B2_BUCKET`,
  plus an email via `DEVCONTAINER_USER_EMAIL` (or `GIT_AUTHOR_EMAIL`). Missing →
  sync is skipped; the attach never fails.
- **Provide `rclone` (>= 1.66) and `gh`** — the feature installs missing ones at
  build time (with a warning) unless `skipInstallSystemPackages`. No `jq` or
  `claude` is required (the wrapper drives the extension's bundled `claude`).

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
  every rebuild, then set `skipInstallSystemPackages: true`. `rclone` must be
  **>= 1.66** (newer than apt's), so use the official script; `gh` needs
  GitHub's apt repo:

  ```dockerfile
  RUN apt-get update \
   && apt-get install -y --no-install-recommends curl unzip ca-certificates \
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
