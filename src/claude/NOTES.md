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
