
# argbash (argbash)

Installs the argbash utility

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/argbash:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the argbash version. | string | 2.10.0 |
| installPrefix | Select the installation prefix. | string | /usr/local |

# Argbash feature

Installs [argbash](https://argbash.readthedocs.io/en/stable/) into /usr/local/bin

The `version` option argument can be looked up here [release page][argbashReleasePage]

The `installPrefix` does not include the `bin` directory, that one is added by the install script. This just sets the `PREFIX=` make file argument, as described in the docs
## Example Usage


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/argbash/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
