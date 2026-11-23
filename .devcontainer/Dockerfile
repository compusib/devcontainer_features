FROM mcr.microsoft.com/devcontainers/javascript-node:1-20-bookworm

# mise (version manager), system-wide: installs the tools of mise.toml (post-create hook). That is go, which
# builds pgtoken's mint (src/auth/pgtoken), and ssh-jwt, which pgtoken's gates ask for the public half of the
# agent's key. The C compiler and make are the image's. The installer auto-detects the architecture (amd64 /
# arm64).
# MISE_INSTALL_FROM_GITHUB=1 pulls the binary from github.com/jdx/mise/releases instead of mise's default CDN
# (mise.en.dev), which is not reachable from every network. The installer is run from a file, not from a pipe: a
# download that breaks off is then no script.
# Activation is NOT set up here: it is centralized in the shared bash repo's ~/.bashrc.d (115_mise.sh), which
# the bashrc feature enables on attach.
RUN curl -fsSL https://mise.run -o /tmp/mise-install.sh \
    && MISE_INSTALL_PATH=/usr/local/bin/mise MISE_INSTALL_FROM_GITHUB=1 sh /tmp/mise-install.sh \
    && rm /tmp/mise-install.sh
