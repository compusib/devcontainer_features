
# Claude (claude)

Installs the private compusib.settings-bridge VS Code extension in place (from a local working tree when available, otherwise a sparse checkout of compusib/ai at the same canonical path — never copied), provisions Claude data sync (~/.claude to Backblaze B2 via rcloneops) on attach, and installs claude-notify-emit so the notify plugin's hooks can raise native OS notifications (relayed by settings-bridge to the host-side notify-host extension) when Claude is waiting on you.

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
| claudePlugins | Space-separated Claude Code plugins (each <name>@<marketplace>) every container using this feature should have installed. Each plugin is installed from the marketplace named by its @<marketplace> suffix (which must be registered via pluginMarketplaces). Installed at each Claude session launch by claude-process-wrapper (set as claudeCode.claudeProcessWrapper) via 'claude plugin install', which also pulls each plugin's full dependency closure. Defaults to the compusib baseline plus the agent-skills plugin from the addy-agent-skills marketplace; override per devcontainer, or set to empty to install none. | string | base-stack@compusib agent-skills@addy-agent-skills |
| defaultPluginConfigs | Before installing each plugin, seed its userConfig defaults (declared in the plugin manifest) into ~/.claude/settings.json, using the bash repo's 'manifest-to-default-user-config' (resolved via BASH_REPO_ROOT). Best-effort and idempotent: fill-only (never overwrites a value you have already set), skips plugins that declare no defaults, and silently no-ops when the helper or a manifest is unavailable. Set false to skip default seeding. | boolean | true |
| pluginMarketplaces | Space-separated list of Claude Code plugin marketplaces to register, each entry 'name|source[|localOverride]'. name must match the @<marketplace> suffix used in claudePlugins; source is the online (git) marketplace URL; the optional localOverride is a directory that, when present and containing .claude-plugin/marketplace.json, is registered as a local 'directory' source instead (the online source is the fallback when it is absent; re-evaluated every container start). Omit the third field for a marketplace that has no local override. The default registers two marketplaces: 'compusib' (git@github.com:compusib/ai.git, local override /workspace/compusib/ai) and 'addy-agent-skills' (git@github.com:paulbalomiri/agent-skills.git, local override /workspace/paulbalomiri/agent-skills). SSH form by default (relies on SSH-agent forwarding). Set to empty to register no marketplaces. | string | compusib|git@github.com:compusib/ai.git|/workspace/compusib/ai addy-agent-skills|git@github.com:paulbalomiri/agent-skills.git|/workspace/paulbalomiri/agent-skills |
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
(`~/.claude/.plugins-ensured`, keyed on plugins + every resolved source + version)
skips the work on later launches. Marketplaces come from `pluginMarketplaces`
(`name|source[|localOverride]` entries); each plugin in `claudePlugins` is installed
against the marketplace named by its own `@<suffix>`. Per marketplace, a
`localOverride` checkout holding `.claude-plugin/marketplace.json` is registered as a
`directory` source, else the git `source` (the fallback). The default registers two
marketplaces — `compusib` and `addy-agent-skills` — each preferring its local
`/workspace/...` checkout and falling back to its GitHub source.

> `claude plugin install` resolves a plugin's direct deps, but a dep it
> *auto-installs* gets only its **first** dep resolved (2.1.143–2.1.177,
> anthropics/claude-code#68449). So the script re-installs each installed plugin
> explicitly, looping until none are new — pulling the full closure
> (`base-stack → base → rclone`).

On attach (`postAttachCommand`), `bootstrap-claude-sync` establishes the
`~/.claude` ↔ Backblaze B2 bisync baseline via `rcloneops` (disable with
`bootstrapClaudeSync: false`). The session-sync hooks themselves ship in the
`rclone` plugin (a dependency pulled in above), not from this feature.

## Native notifications

The feature installs `claude-notify-emit` on `PATH`. The `notify` plugin (pulled in
via `base → notify`, like the rclone hooks) registers Claude hooks that call it when
the AI is **waiting on you** — a tool-permission prompt (`PermissionRequest`),
`AskUserQuestion`, `ExitPlanMode`, 60s idle (`Notification` matcher `idle_prompt`) — or
**finishes** a turn (`Stop`). `PermissionRequest` is used for permission prompts because
the `Notification` hook doesn't fire in the VS Code extension (anthropics/claude-code
#11156). `claude-notify-emit` appends one JSON line to a **per-window** queue
`~/.claude/notify-queue/<workspace>-<scope>.jsonl` (scope = remote in a container, local
otherwise), so the settings-bridge relay in each window drains only its own events and
the banner fires from the window it belongs to — not a random window sharing `~/.claude`.
It writes nothing to stdout, so it can't perturb a hook's decision.

That queue is drained by the **settings-bridge** `notify-relay` (workspace extension,
in the container), which forwards each event over VS Code's extension-host command
channel to the **`notify-host`** UI extension on the user's machine, which shows a
native OS banner. The command channel is the only transport that works for a **remote**
devcontainer. `notify-host` is **not** installed by this feature — it must be installed
host-side once (it is a UI extension; the feature can only provision the container).
Without it the queue is simply drained and discarded (no error), and `settings-bridge`
shows a one-time, dismissible prompt with the install command.

**Host setup (one-time, per Mac):** install `notify-host`, plus `terminal-notifier` and
`AltTab` for click-to-focus, and grant the macOS permissions — see the checklist at the
top of `compusib/ai/vscode/notify-host/README.md`. The extensions nudge you when a piece
is missing; suppress with `compusib.notify.suppressSetupPrompts`.

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

- **For marketplace/plugin development**, mount the checkout at the local-override
  path baked into the matching `pluginMarketplaces` entry (e.g. `/workspace/compusib/ai`
  for `compusib`, `/workspace/paulbalomiri/agent-skills` for `addy-agent-skills`): the
  feature points Claude at your working tree instead of the published git marketplace,
  so edits show up on the next start with no push/pull.

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
