## Starship extension

Installs [starship shell](https://starship.rs/).


### `startFromBashRc` Option

This option only has an effect if `ghcr.io/compusib/devcontainer_features/bashrc` is installed alongside starship.
If this is not the case the .bashrc can be manually altered to start starship by appending this line to `~.bashrc`

```bash
  eval $(starship init bash)
```

### ``