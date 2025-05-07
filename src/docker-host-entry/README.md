
# docker-host-entry (docker-host-entry)

set startup options

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/docker-host-entry:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| dockerHostAlias | Set the docker host alias to add to /etc/hosts. The container's host ip address will be aliased by this name inside the container. | string | host |
| useBashRc | Sets the docker host from bash_rc. See notes  | boolean | true |

## Starship extension

Adds an entry to `/etc/hosts`
the default alias is `"host"`
Issuing commands such as `ssh host` or `ping host` will communicate with the host ip from inside the container


### `useBashRc` Option

This option only has an effect if `ghcr.io/compusib/devcontainer_features/bashrc` is installed alongside starship.
If this is not the case the .bashrc can be manually altered to start starship by appending this line to `~.bashrc`

```bash
  eval $(starship init bash)
```

### ``

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/docker-host-entry/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
