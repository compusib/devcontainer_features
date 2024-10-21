
# starship (starship)

set startup options

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/starship:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| configFile | Config file location. If a file is found at that location, then the STARSHIP_CONFIG env is pointed to it | string | \$GIT_ROOT/.devcontainer/config/starship.toml |
| startFromBashRc | Sets starship up to start from bashrc. Turn off to manually start starship shell. See notes  | boolean | true |

## Starship extension

Installs [starship shell](https://starship.rs/) using the feature [`ghcr.io/devcontainers-extra/features/starship`](https://github.com/devcontainers-extra/features/tree/main/src/starship).


### `startFromBashRc` Option

This option only has an effect if `ghcr.io/compusib/devcontainer_features/bashrc` is installed alongside starship.
If this is not the case the .bashrc can be manually altered to start starship by appending this line to `~.bashrc`

```bash
  eval $(starship init bash)
```

### ``

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/starship/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
