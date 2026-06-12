
# bashrc (bashrc)

set startup options

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/bashrc:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| gitRoot | Where the root of the git directory is located. Defaults to the value of the workspace folder | string | \$CONTAINER_WORKSPACE_FOLDER |
| pathAppend | Appends this Path to the container PATH environment variable using ~/.bashrc.d/100_bash_path_append.sh | string | \$CONTAINER_WORKSPACE_FOLDER/scripts |
| compusibBashRepoRoot | Path to the compusib bash repo checkout. Exported as BASH_REPO_ROOT via ~/.bashrc.d/005_BASH_REPO_ROOT_env.sh, and if <path>/bin/bashrc exists it is run as `bin/bashrc enable --all` during postAttachCommand. | string | /workspace/compusib/bash |

## bashrc feature

Adds customizations included from  `~/.bashrc.d` directory.

### the `~/.bashrc.d`

This feature creates the `~/.bashrc.d` and then adds a snippet in .bashrc to **dot-include** any files 
with the `sh` extension from that directory (i.e. all `. ~/.bashrc.d/*.sh` files)

The `bashrc` also adds the `containerWorkspaceFolder` setting from `devcontainer.json` as the environment variable `CONTAINER_WORKSPACE_FOLDER`, by creating the file `~/.bashrc.d/000_CONTAINER_WORKSPACE_FOLDER_env.sh`.

Files in `~/.bashrc.d/` are included into `~/.bashrc` in **alphabetical** order.

### `gitRoot` Option

This sets a `GIT_ROOT` environment variable. It defaults to `$CONTAINER_WORKSPACE_FOLDER`. When supplying the value, the same
Expression s present in the container.

The `GIT_ROOT` environment variable is set in the file `~/.bashrc.d/010_GIT_ROOT_env.sh` of the container user home.

### `pathAppend` Option

The `pathAppend` option is interpolated by`bash`. `
# bashrc (bashrc)

set startup options

## Example Usage

```json
"features": {
    "#{Registry}/#{Namespace}/bashrc:#{Version}": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| gitRoot | Where the root of the git directory is located. Defaults to the value of the workspace folder | string | \$CONTAINER_WORKSPACE_FOLDER |
| pathAppend | Appends this Path to the container PATH environment variable using ~/.bashrc.d/100_bash_path_append.sh | string | \$CONTAINER_WORKSPACE_FOLDER/scripts |
| compusibBashRepoRoot | Path to the compusib bash repo checkout. Exported as BASH_REPO_ROOT via ~/.bashrc.d/005_BASH_REPO_ROOT_env.sh, and if <path>/bin/bashrc exists it is run as `bin/bashrc enable --all` during postAttachCommand. | string | /workspace/compusib/bash |
#{Customizations}
characters need to be escaped like so: `\\
# bashrc (bashrc)

set startup options

## Example Usage

```json
"features": {
    "#{Registry}/#{Namespace}/bashrc:#{Version}": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| gitRoot | Where the root of the git directory is located. Defaults to the value of the workspace folder | string | \$CONTAINER_WORKSPACE_FOLDER |
| pathAppend | Appends this Path to the container PATH environment variable using ~/.bashrc.d/100_bash_path_append.sh | string | \$CONTAINER_WORKSPACE_FOLDER/scripts |
| compusibBashRepoRoot | Path to the compusib bash repo checkout. Exported as BASH_REPO_ROOT via ~/.bashrc.d/005_BASH_REPO_ROOT_env.sh, and if <path>/bin/bashrc exists it is run as `bin/bashrc enable --all` during postAttachCommand. | string | /workspace/compusib/bash |
#{Customizations}
.
This is to prevent vscode from substituting the `
# bashrc (bashrc)

set startup options

## Example Usage

```json
"features": {
    "#{Registry}/#{Namespace}/bashrc:#{Version}": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version to install. | string | latest |
| gitRoot | Where the root of the git directory is located. Defaults to the value of the workspace folder | string | \$CONTAINER_WORKSPACE_FOLDER |
| pathAppend | Appends this Path to the container PATH environment variable using ~/.bashrc.d/100_bash_path_append.sh | string | \$CONTAINER_WORKSPACE_FOLDER/scripts |
| compusibBashRepoRoot | Path to the compusib bash repo checkout. Exported as BASH_REPO_ROOT via ~/.bashrc.d/005_BASH_REPO_ROOT_env.sh, and if <path>/bin/bashrc exists it is run as `bin/bashrc enable --all` during postAttachCommand. | string | /workspace/compusib/bash |
#{Customizations}
 variable, and for json to accept the slash which itself needs escaping to`\\`.
`\\${CONTAINER_WORKSPACE_FOLDER}`  as an example refers to the mounted root of the container. 

The path is mofied in the file `~/.bashrc.d/100_bash_path_append.sh` of the container user home.

### `compusibBashRepoRoot` Option

This points to the [compusib `bash`](https://github.com/compusib/bash) repository checkout, defaulting to `/workspace/compusib/bash`. Its value is exported as the `BASH_REPO_ROOT` environment variable via the file `~/.bashrc.d/005_BASH_REPO_ROOT_env.sh`.

During `postAttachCommand` (so the mounted repo is available), if `<compusibBashRepoRoot>/bin/bashrc` exists and is executable, the feature runs `bin/bashrc enable --all` to link the repo's `~/.bashrc.d` fragments. When the path or script is absent the step is skipped without failing the hook.






---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/bashrc/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
