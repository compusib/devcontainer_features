
# Claude (claude)

Installs the private `compusib.settings-bridge` VS Code extension and links the container's
`~/.claude` to the host home when it is mounted.

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
| settingsBridgeRepoPath | Local working tree of settingsBridgeRepo, if it is already checked out into the container (e.g. bind-mounted for extension development). When it contains a *.vsix at settingsBridgeVsixDir it is used as the source, preferred over cloning. Set to empty to always download. | string | /workspace/compusib/ai |
| settingsBridgeRepo | Git URL of the repo to clone the settings-bridge .vsix from when no local working tree (settingsBridgeRepoPath) is present. SSH form by default (relies on SSH-agent forwarding); use the https URL if your container has an HTTPS credential helper instead. | string | git@github.com:compusib/ai.git |
| settingsBridgeRef | Git ref (branch/tag) to fetch when downloading the .vsix. | string | main |
| settingsBridgeVsixDir | Directory holding the built *.vsix, relative to the repo root. Applies identically to settingsBridgeRepoPath and to a fresh clone of settingsBridgeRepo. | string | vscode/settings-bridge/dist |
| extensionId | Extension id (publisher.name) used for the already-installed idempotency guard. | string | compusib.settings-bridge |
| hostHomeMountpoint | Location where the host home directory is mounted into the container. When it contains a .claude directory, the container's ~/.claude is symlinked to it. A leading ~/ is expanded to $HOME at runtime. | string | ~/host-home |

## How it works

The extension cannot be installed via `customizations.vscode.extensions` (that only accepts
marketplace ids) and it must not be vendored into the feature image. So the feature installs two
small helper scripts at build time and runs them from `postAttachCommand`, where the container's
git auth and the `code` CLI are both available:

- **`link-host-claude`** — if `hostHomeMountpoint` contains a `.claude` directory, symlinks
  `~/.claude` to it. An existing symlink is repointed; a real `~/.claude` directory is left
  untouched.
- **`install-settings-bridge`** — installs the `compusib.settings-bridge` extension. The source is
  always a working tree of the repo; the `.vsix` lives at `<repo-root>/settingsBridgeVsixDir`
  whether that root is a local checkout or a fresh clone:
  - **Local working tree present** (`settingsBridgeRepoPath/settingsBridgeVsixDir` contains a
    `*.vsix`): installs from it with `--force` so in-development edits propagate on each rebuild,
    and removes any previously downloaded copy from the home cache.
  - **No local working tree**: skips when the extension is already installed; otherwise performs a
    shallow, sparse `git clone` of `settingsBridgeRepo` (reusing the container's own GitHub auth —
    SSH-agent forwarding or an HTTPS credential helper), caches the `*.vsix` under
    `~/.cache/claude-feature/settings-bridge/`, and installs it.

Nothing extension-specific is baked into the feature image; the `.vsix` is always obtained at
runtime from the local working tree or git.

### Authentication

When downloading, the feature reuses whatever GitHub auth the container already has. The default
`settingsBridgeRepo` is the SSH form (`git@github.com:compusib/ai.git`) so SSH-agent forwarding
works out of the box. If your container authenticates over HTTPS instead, set `settingsBridgeRepo`
to `https://github.com/compusib/ai.git`.

---

_Note: This file may be auto-regenerated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/claude/devcontainer-feature.json)._
