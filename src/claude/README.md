
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
| pluginMarketplace | Claude Code plugin marketplace registered (via 'claude plugin marketplace add') before installing claudePlugins. SSH form by default (relies on SSH-agent forwarding). | string | git@github.com:compusib/ai.git |
| bootstrapClaudeSync | Run 'rcloneops claude-bootstrap' on attach to provision Claude data sync for ~/.claude (bisync baseline + session hooks against Backblaze B2). Requires rcloneops on PATH (from the bashrc feature) and the DEVCONTAINERS_B2_* credentials in the env; cleanly no-ops otherwise. Set false to disable entirely. | boolean | true |

## System package dependencies

This feature relies on a few system packages at runtime:

- **`rclone`** — used to move/sync Claude data. Needs **>= 1.66** because
  `rcloneops` drives `rclone bisync` with flags (`--conflict-resolve`,
  `--resilient`, `--recover`, `--max-lock`) introduced in that release.
- **`jq`** — used to read/manipulate JSON config.
- **`gh`** — the GitHub CLI.

At build time the feature checks whether each command is already available:

- `jq` and `gh`: if present it does nothing; if missing it installs the package
  via `apt-get` as a fallback and prints a warning recommending you bake it into
  your devcontainer image instead.
- `rclone`: the version matters, not just presence. Debian's apt build lags far
  behind (e.g. 1.60), so when `rclone` is missing **or older than 1.66** the
  feature installs the latest via rclone's official script
  (`curl https://rclone.org/install.sh | bash`) and warns. An already-recent
  `rclone` is left untouched.

### Recommended: install them in your Dockerfile

Installing these in your devcontainer's Dockerfile bakes them into the image so
they don't get re-installed on every rebuild and the build stays reproducible.

`jq` is in Debian's default repos. `rclone` must be **>= 1.66**, which the apt
build is usually too old to satisfy, so install it from rclone's official script
instead:

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl unzip ca-certificates \
 && curl -fsSL https://rclone.org/install.sh | bash \
 && rm -rf /var/lib/apt/lists/*
```

`gh` is **not** in Debian's default repos — register GitHub's apt repository
first (the feature prints these exact lines when it falls back to installing it):

```dockerfile
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/gh.gpg \
 && chmod go+r /etc/apt/keyrings/gh.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/gh.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/gh.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*
```

### Skipping the fallback install

Once the packages are provided by your image, set `skipInstallSystemPackages`
to `true` so the feature does not attempt to install them at build time:

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/claude:0": {
        "skipInstallSystemPackages": true
    }
}
```

## Claude bootstrap on attach (`bootstrap-claude-sync`)

On `postAttachCommand`, the feature runs `bootstrap-claude-sync`, which:

1. **Ensures the plugin marketplace + plugins are installed.** It registers
   `pluginMarketplace` (default `git@github.com:compusib/ai.git`) with
   `claude plugin marketplace add`, then installs each plugin in `claudePlugins`
   (default `base-stack@compusib`). Idempotent; skips cleanly if the `claude`
   CLI is absent. The feature puts the VS Code "Claude Code" extension's bundled
   `claude` binary on `PATH` (see [Putting `claude` on `PATH`](#putting-claude-on-path)),
   so this step normally runs even without a separately-installed CLI.
2. **Provisions data sync for `~/.claude`** via
   `rcloneops claude-bootstrap --no-dry-run` (establishes the bisync baseline and
   installs `SessionStart`/`SessionEnd` sync hooks). Needs the B2 credentials in
   the container env (see below); never fails the attach. Disable with
   `bootstrapClaudeSync: false`.

`~/.claude` is synced exclusively through `rcloneops` (bidirectional `rclone
bisync` to Backblaze B2) — there is no host-directory symlinking.

### B2 sync credentials

`rcloneops` reads its Backblaze B2 credentials from the container environment
(see `man rcloneops`). The remote-touching bootstrap step needs:

- `DEVCONTAINERS_B2_ACCOUNT` — B2 account / application key ID.
- `DEVCONTAINERS_B2_KEY` — B2 application key.
- `DEVCONTAINERS_B2_BUCKET` — B2 bucket name.
- account email via `DEVCONTAINER_USER_EMAIL`, falling back to `GIT_AUTHOR_EMAIL`.

These are **secrets**: forward them from the host rather than committing them.
In your devcontainer's `devcontainer.json`:

```jsonc
"containerEnv": {
    "DEVCONTAINERS_B2_ACCOUNT": "${localEnv:DEVCONTAINERS_B2_ACCOUNT}",
    "DEVCONTAINERS_B2_KEY": "${localEnv:DEVCONTAINERS_B2_KEY}",
    "DEVCONTAINERS_B2_BUCKET": "${localEnv:DEVCONTAINERS_B2_BUCKET}"
}
```

If the credentials are missing, `bootstrap-claude-sync` cleanly no-ops (the
attach never fails); sync simply does not happen until they are provided.

### Requires the `bashrc` feature + the bash repo mounted

`rcloneops` is **not** bundled by this feature. It ships in the compusib bash
repo (`bin/rcloneops`, origin `git@github.com:compusib/bash.git`) and reaches
`PATH` only via the **`bashrc`** feature
(`ghcr.io/compusib/devcontainer_features/bashrc`), which this feature declares in
`dependsOn` so it is installed automatically.

The `bashrc` feature does **not** clone the bash repo — it expects the repo to be
**mounted into the container** at its `compusibBashRepoRoot` (default
`/workspace/compusib/bash`). That mount is what puts `bin/rcloneops` on `PATH`
and points `BASH_LIB_DIR` at the repo's `lib/` (so `rcloneops` can source its
sync library). Without the mount, `rcloneops` is absent and the sync step is
skipped.

### Putting `claude` on `PATH`

The VS Code "Claude Code" extension ships a native `claude` binary but does not
put it on `PATH`, and it installs at *attach* time under a directory whose name
carries the extension version and CPU arch, e.g.
`~/.vscode-server/extensions/anthropic.claude-code-<version>-<arch>/resources/native-binary/claude`.

So at build time the feature drops a `~/.bashrc.d/190_claude_path.sh` fragment
that resolves that binary with a glob (newest version wins) and prepends its
directory to `PATH` when no `claude` is already reachable. This is what lets
`bootstrap-claude-sync` find `claude` and install the configured plugins. A
real, separately-installed `claude` CLI on `PATH` always takes precedence and is
left untouched.

The fragment lands in `~/.bashrc.d` only when the **`bashrc`** feature created
that directory (it is a `dependsOn`); otherwise the same setup is appended to
`~/.bashrc`.

### Required tools

`bootstrap-claude-sync` uses `claude` (for plugins) and `rcloneops` (for sync;
which itself needs `rclone` and `jq` — see above). Each step is skipped with a
warning if its tool is not on `PATH`, so the attach never fails.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/claude/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
