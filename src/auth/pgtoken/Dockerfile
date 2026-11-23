# The image that builds pgtoken for a release: `make dist`, the Makefile beside this file. Context: the repo's root.
#
# Debian 12: the libraries run on Debian 12 and on Debian 13, and are built against the older libc. Go is the one
# the repo's mise.toml pins, installed by mise as in the dev container. The image has the machine's own
# architecture and compiles for the other one with Debian's cross compiler: no emulation, on a Mac and on
# Intel/AMD alike.
#
# The build fails when a library needs more than libc.so.6 or a newer libc than Debian 12's, when the module
# exports more than the entry point of PostgreSQL 19's module ABI, or when the loader exports anything: it is in
# every program a shell starts, and replaces no function of any.
FROM --platform=$BUILDPLATFORM debian:12 AS debian

# The name of the target's C compiler and binutils, by its architecture. Another architecture has no stage here,
# and the build stops at the FROM below.
FROM debian AS for-amd64
ENV GNU=x86_64-linux-gnu
FROM debian AS for-arm64
ENV GNU=aarch64-linux-gnu

FROM for-$TARGETARCH AS build
ARG BUILDARCH
ARG TARGETARCH

# Debian's compiler for this machine: it answers to the machine's own $GNU-gcc too. For the other architecture,
# Debian's cross compiler and that architecture's libc.
RUN <<EOF
  set -eux
  cross=
  [ "$TARGETARCH" = "$BUILDARCH" ] || cross="gcc-$(echo "$GNU" | tr _ -) libc6-dev-$TARGETARCH-cross"
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl make gcc libc6-dev $cross
  rm -rf /var/lib/apt/lists/*
EOF

# mise, and with it the go of mise.toml. MISE_INSTALL_FROM_GITHUB takes mise from github.com/jdx/mise/releases:
# its own CDN (mise.en.dev) is not reachable from every network. The installer is run from a file, not from a
# pipe: a download that breaks off is then no script.
COPY mise.toml /src/mise.toml
RUN <<EOF
  set -eux
  curl -fsSL https://mise.run -o /tmp/mise-install.sh
  MISE_INSTALL_PATH=/usr/local/bin/mise MISE_INSTALL_FROM_GITHUB=1 sh /tmp/mise-install.sh
  rm /tmp/mise-install.sh
  cd /src
  export MISE_TRUSTED_CONFIG_PATHS=/src
  mise install go
  ln -s "$(mise where go)/bin/go" /usr/local/bin/go
  go version
EOF

COPY src/auth/pgtoken/Makefile src/auth/pgtoken/libpq-oauth.c src/auth/pgtoken/pgtoken.c /src/pgtoken/
COPY src/auth/pgtoken/oauth /src/pgtoken/oauth
RUN <<EOF
  set -eu
  cd /src/pgtoken
  GOARCH=$TARGETARCH make CC=$GNU-gcc OUT=/out
  exported() { $GNU-objdump -T "$1" | awk '$2 == "g" && $4 != "*UND*" { printf "%s ", $NF }'; }
  for library in /out/libpq-oauth.so /out/pgtoken-oauth.so /out/pgtoken.so; do
    needed=$($GNU-objdump -p "$library" | awk '$1 == "NEEDED" { printf "%s ", $2 }')
    [ "$needed" = "libc.so.6 " ] || { echo "$library needs more than libc: $needed" >&2; exit 1; }
    newest=$($GNU-objdump -T "$library" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)
    [ "$(printf '%s\nGLIBC_2.36\n' "$newest" | sort -V | tail -1)" = GLIBC_2.36 ] \
      || { echo "$library needs $newest: newer than Debian 12's libc" >&2; exit 1; }
    echo "$library: needs $needed, at most $newest"
  done
  [ "$(exported /out/libpq-oauth.so)" = "pg_start_oauthbearer " ] \
    || { echo "the module exports: $(exported /out/libpq-oauth.so)" >&2; exit 1; }
  [ -z "$(exported /out/pgtoken.so)" ] || { echo "the loader exports: $(exported /out/pgtoken.so)" >&2; exit 1; }
EOF

# What `--output type=local` writes: the three libraries, and nothing else.
FROM scratch
COPY --from=build /out/libpq-oauth.so /out/pgtoken-oauth.so /out/pgtoken.so /
