## System package dependencies

This feature relies on a few system packages at runtime:

- **`rclone`** — used to move/sync Claude data.
- **`jq`** — used to read/manipulate JSON config.
- **`gh`** — the GitHub CLI.

At build time the feature checks whether each command is already available:

- If present, it does nothing.
- If missing, it installs the package via `apt-get` as a fallback and prints a
  warning recommending you bake it into your devcontainer image instead.

### Recommended: install them in your Dockerfile

Installing these in your devcontainer's Dockerfile bakes them into the image so
they don't get re-installed on every rebuild and the build stays reproducible.

`rclone` and `jq` are in Debian's default repos:

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends rclone jq \
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

> The `apt` version of `rclone` can lag behind upstream. If you need the latest
> release, install it via the official script instead:
> `RUN curl https://rclone.org/install.sh | bash`

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

On `postAttachCommand` (after `link-host-claude`), the feature runs
`bootstrap-claude-sync`, which:

1. **Ensures the plugin marketplace + plugins are installed.** It registers
   `pluginMarketplace` (default `git@github.com:compusib/ai.git`) with
   `claude plugin marketplace add`, then installs each plugin in `claudePlugins`
   (default `base-stack@compusib`). Idempotent; skips cleanly if the `claude`
   CLI is absent.
2. **Provisions data sync for a container-local `~/.claude`** via
   `rcloneops claude-bootstrap --no-dry-run` (establishes the bisync baseline and
   installs `SessionStart`/`SessionEnd` sync hooks). Needs the `DEVCONTAINERS_B2_*`
   credentials in the container env; never fails the attach. Disable with
   `bootstrapClaudeSync: false`.

### External (host) mount of `~/.claude`

When `link-host-claude` has symlinked `~/.claude` into the mounted host home,
the **host owns the data and its syncing**, so `bootstrap-claude-sync` **does not
run `rcloneops`** there:

- Establishing a bisync baseline from the container would contend with the host.
- The session hooks embed *this container's* absolute `rcloneops` path
  (`"<path>" claude --no-dry-run`); writing them into the host-shared
  `settings.json` would break the host's own Claude sessions.

The plugin marketplace + plugins are still installed in this case.

### Required tools

`bootstrap-claude-sync` uses `claude` (for plugins) and `rcloneops` (for sync;
which itself needs `rclone` and `jq` — see above). Each step is skipped with a
warning if its tool is not on `PATH`, so the attach never fails.
