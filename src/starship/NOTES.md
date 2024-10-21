## Starship extension

Installs [starship shell](https://starship.rs/) using the feature [`ghcr.io/devcontainers-extra/features/starship`](https://github.com/devcontainers-extra/features/tree/main/src/starship).


### `startFromBashRc` Option

This option only has an effect if `ghcr.io/compusib/devcontainer_features/bashrc` is installed alongside starship.
If this is not the case the .bashrc can be manually altered to start starship by appending this line to `~.bashrc`

```bash
  eval $(starship init bash)
```

### ``