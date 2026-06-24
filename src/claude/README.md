
# Claude (claude)

Installs the private compusib.settings-bridge VS Code extension in place (from a local working tree when available, otherwise a sparse checkout of compusib/ai at the same canonical path — never copied) and provisions Claude data sync (~/.claude to Backblaze B2 via rcloneops) on attach.

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
| settingsBridgeRepoPath | Canonical path of the compusib/ai working tree, which is also exactly the path customizations.vscode.extensions points into. If it already holds the built vsix (bind-mounted working tree, or a prior checkout) the extension installs from it in place. If the path does not exist, the feature sparse-checks-out settingsBridgeRepo here. An existing repo without the vsix is left untouched (never cloned over). | string | /workspace/compusib/ai |
| settingsBridgeRepo | Git URL sparse-checked-out into settingsBridgeRepoPath when that path does not yet exist. SSH form by default (relies on the forwarded SSH agent, which is present at onCreate). | string | git@github.com:compusib/ai.git |
| settingsBridgeRef | Git ref (branch/tag) to check out when fetching the vsix. | string | main |
| settingsBridgeVsixDir | Directory holding the built compusib.settings-bridge.vsix, relative to settingsBridgeRepoPath. The customizations.vscode.extensions entry is <settingsBridgeRepoPath>/<settingsBridgeVsixDir>/compusib.settings-bridge.vsix (a stable, version-less filename). | string | vscode/settings-bridge/dist |
| claudePlugins | Space-separated Claude Code plugins (each <name>@<marketplace>) every container using this feature should have installed from pluginMarketplace. Installed at each Claude session launch by claude-process-wrapper (set as claudeCode.claudeProcessWrapper) via 'claude plugin install', which also pulls each plugin's full dependency closure. Defaults to the compusib baseline; override per devcontainer, or set to empty to install none. | string | base-stack@compusib |
| defaultPluginConfigs | Before installing each plugin, seed its userConfig defaults (declared in the plugin manifest) into ~/.claude/settings.json, using the bash repo's 'manifest-to-default-user-config' (resolved via BASH_REPO_ROOT). Best-effort and idempotent: fill-only (never overwrites a value you have already set), skips plugins that declare no defaults, and silently no-ops when the helper or a manifest is unavailable. Set false to skip default seeding. | boolean | true |
| pluginMarketplaces | Space-separated list of Claude Code plugin marketplaces to register, each entry 'name|source[|localOverride]'. name must match the @<marketplace> suffix used in claudePlugins; source is the online (git) marketplace URL; the optional localOverride is a directory that, when present and containing .claude-plugin/marketplace.json, is registered as a local 'directory' source instead (re-evaluated every container start). Omit the third field for a marketplace that has no local override. Example: 'compusib|git@github.com:compusib/ai.git|/workspace/compusib/ai partner|git@github.com:partner/plugins.git'. When empty (the default), a single marketplace is synthesized from pluginMarketplace + pluginMarketplaceLocalOverride, named after the first claudePlugins entry's @<marketplace> suffix (backward-compatible single-marketplace mode). | string | - |
| pluginMarketplace | Single-marketplace shorthand: online (git) source for the compusib Claude Code plugin marketplace, used only when pluginMarketplaces is empty. Registered at session launch by claude-process-wrapper via 'claude plugin marketplace add'; used unless pluginMarketplaceLocalOverride names a mounted local checkout. SSH form by default (relies on SSH-agent forwarding). For more than one marketplace, use pluginMarketplaces instead. | string | git@github.com:compusib/ai.git |
| pluginMarketplaceLocalOverride | Single-marketplace shorthand (used only when pluginMarketplaces is empty): directory that, when present and containing .claude-plugin/marketplace.json, makes the feature register the compusib marketplace as a local 'directory' source pointing at it (instead of the online pluginMarketplace git source). Re-evaluated on every container start; set to empty to always use the online source. | string | /workspace/compusib/ai |
| bootstrapClaudeSync | Run 'rcloneops claude-bootstrap' on attach to establish the ~/.claude bisync baseline against Backblaze B2. (The session-sync hooks ship in the rclone Claude Code plugin, enabled declaratively via claudePlugins — not installed here.) Requires rcloneops on PATH (from the bashrc feature) and the DEVCONTAINERS_B2_* credentials in the env; cleanly no-ops otherwise. Set false to disable entirely. | boolean | true |

## Customizations

### VS Code Extensions

- `/workspace/compusib/ai/vscode/settings-bridge/dist/compusib.settings-bridge.vsix`

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
