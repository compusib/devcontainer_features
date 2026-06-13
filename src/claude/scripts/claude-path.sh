# Put the VS Code "Claude Code" extension's bundled `claude` binary on PATH.
#
# Installed into ~/.bashrc.d by the `claude` devcontainer feature.
#
# The extension ships a native `claude` binary but does not put it on PATH, and
# it installs at *attach* time (after the image is built) under a directory whose
# name carries the extension version and CPU arch, e.g.
#   ~/.vscode-server/extensions/anthropic.claude-code-<version>-<arch>/resources/native-binary/claude
# so the location can only be resolved at shell-init time. Resolve it with a glob
# and pick the highest version. If a `claude` is already reachable (a real CLI
# install, or this fragment already ran) we leave PATH untouched.
if ! command -v claude >/dev/null 2>&1; then
    # `ls` over the glob: no match → empty (stderr discarded); `sort -V` then
    # picks the newest version (handles 2.1.9 vs 2.1.177 correctly).
    _claude_bin=$(ls -d "$HOME"/.vscode-server*/extensions/anthropic.claude-code-*/resources/native-binary/claude \
        "$HOME"/.cursor-server*/extensions/anthropic.claude-code-*/resources/native-binary/claude \
        2>/dev/null | sort -V | tail -n 1)
    if [ -n "$_claude_bin" ] && [ -x "$_claude_bin" ]; then
        _claude_dir=$(dirname "$_claude_bin")
        case ":$PATH:" in
            *":$_claude_dir:"*) ;;                 # already present
            *) PATH="$_claude_dir:$PATH"; export PATH ;;
        esac
    fi
    unset _claude_bin _claude_dir
fi
