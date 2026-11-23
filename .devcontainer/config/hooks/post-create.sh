#!/usr/bin/env bash
# post-create hook (devcontainer postCreateCommand).
#
# Installs the tools pinned in the repo's mise.toml [tools]: go, and ssh-jwt, which mise builds with that go. It
# also writes mise's shims, which devcontainer.json puts on VS Code's PATH.
#
# Runs once at create, as the remote user (node), in the workspaceFolder with the repo mounted; the config is
# trusted through MISE_TRUSTED_CONFIG_PATHS (devcontainer.json containerEnv). Never hard-fails create: a failed
# install is a warning, re-runnable by hand.
set -uo pipefail

echo "[post-create] installing mise tools from mise.toml…"
if mise install; then
  echo "[post-create] mise tools installed."
else
  echo "[post-create] WARNING: 'mise install' failed (network?). Re-run by hand: mise install" >&2
fi
exit 0
