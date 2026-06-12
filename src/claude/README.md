
# Claude (claude)

Installs the private compusib.settings-bridge VS Code extension (from a local working tree when available, otherwise cloned from git at runtime) and links the container ~/.claude to the host home when mounted.

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



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/claude/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
