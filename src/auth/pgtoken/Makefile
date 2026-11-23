# pgtoken: the three libraries, built side by side.
#   libpq-oauth.so    the module: what libpq 19 loads when a server asks for a token (C, small)
#   pgtoken-oauth.so  the mint: what the module loads when a token has to be minted (Go, needs nothing but libc)
#   pgtoken.so        the loader: what is preloaded where libpq is 18, and loads the module (C, small)
#
#   make        for this machine, into build/: what test/auth/pgtoken/gates.sh tries
#   make dist   for a release: linux/amd64 and linux/arm64, each built in the image of the Dockerfile beside this
#               file (Debian 12, go as the repo's mise.toml pins it), into dist/linux_<arch>/. The feature's
#               install.sh takes them from there. Needs docker alone, on a Mac and on Intel/AMD alike.
# For another architecture than the machine's, CC is its C compiler and GOARCH its name to go: the Dockerfile
# sets both.
OUT ?= build
CC = gcc
ARCHS ?= amd64 arm64

all: $(OUT)/libpq-oauth.so $(OUT)/pgtoken-oauth.so $(OUT)/pgtoken.so

# The name libpq 19 asks the linker for: its soname too, so that ldconfig lists it.
$(OUT)/libpq-oauth.so: libpq-oauth.c
	@mkdir -p $(OUT)
	$(CC) -shared -fPIC -O2 -Wall -Wextra -fvisibility=hidden -Wl,-soname,libpq-oauth.so -o $@ libpq-oauth.c

$(OUT)/pgtoken.so: pgtoken.c
	@mkdir -p $(OUT)
	$(CC) -shared -fPIC -O2 -Wall -Wextra -fvisibility=hidden -o $@ pgtoken.c

$(OUT)/pgtoken-oauth.so: oauth/main.go oauth/go.mod
	@mkdir -p $(OUT)
	cd oauth && CGO_ENABLED=1 CC=$(CC) go build -buildmode=c-shared -trimpath -ldflags='-s -w' -o $(abspath $@) .
	@rm -f $(OUT)/pgtoken-oauth.h

dist:
	for arch in $(ARCHS); do \
	  docker buildx build --platform linux/$$arch --output type=local,dest=dist/linux_$$arch -f Dockerfile ../../.. || exit 1; \
	done

.PHONY: all dist
