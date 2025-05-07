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