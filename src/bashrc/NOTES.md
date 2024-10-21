## bashrc feature

Adds customizations included from  `~/.bashrc.d` directory.
This container creates the `~/.bashrc.d` and then adds a snippet in .bashrc to **dot-include** any files 
with the `sh` extension from that directory (i.e. all `. ~/.bashrc.d/*.sh` files)

The `bashrc` also adds the `containerWorkspaceFolder` setting from `devcontainer.json` as the environment variable `CONTAINER_WORKSPACE_FOLDER`, by creating the file `~/.bashrc.d/CONTAINER_WORKSPACE_FOLDER_env.sh`.

to include this container feature add this entry to the `features:{...}` inside `.devcontainer/devcontainer.json` :
`"ghcr.io/compusib/devcontainer_features/bashrc:1": {}`
