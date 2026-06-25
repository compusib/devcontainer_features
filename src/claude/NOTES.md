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
#11156). `claude-notify-emit` appends one JSON line to `~/.claude/notify-queue.jsonl`
(it writes nothing to stdout, so it can't perturb a hook's decision).

That queue is drained by the **settings-bridge** `notify-relay` (workspace extension,
in the container), which forwards each event over VS Code's extension-host command
channel to the **`notify-host`** UI extension on the user's machine, which shows a
native OS banner. The command channel is the only transport that works for a **remote**
devcontainer. `notify-host` is **not** installed by this feature — it must be installed
host-side once (it is a UI extension; the feature can only provision the container). See
`compusib/ai/vscode/notify-host/README.md`. Without it, the queue is simply drained and
discarded — no error.

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
