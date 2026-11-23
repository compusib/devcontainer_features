#!/bin/bash
# install-pgtoken.sh <the directory of the three built files> <the home of the user whose shells get the check>
#
# Installs pgtoken as the auth feature has it: the feature's install.sh runs this, and so does gate L
# (test/auth/pgtoken/gates.sh) in each of its clients.
set -eu
built=$1 home=$2 dir=/usr/local/lib/pgtoken

install -d "$dir"
install -m 0644 "$built/libpq-oauth.so" "$built/pgtoken-oauth.so" "$built/pgtoken.so" "$dir/"

# libpq 19 loads libpq-oauth.so by that name, through the linker's own search. This directory is first on it
# (000-: before the architecture's own, and before /usr/local/lib), so the module is found, and before
# PostgreSQL's own module of that name, should its package be installed.
echo "$dir" > /etc/ld.so.conf.d/000-pgtoken.conf
ldconfig

install -d "$home/.bashrc.d"
cat > "$home/.bashrc.d/130_pgtoken.sh" <<'CHECK'
# pgtoken (the auth feature). libpq 19 loads pgtoken's module, libpq-oauth.so, by itself. libpq 18 cannot: there
# pgtoken.so is preloaded, and loads the module the way libpq 19 does. When no libpq here is an 18 any more, this
# file and pgtoken.so can go.
case "$(readlink -f /usr/lib/*/libpq.so.5 2>/dev/null)" in
    */libpq.so.5.18)
        case ":${LD_PRELOAD:-}:" in
            *:/usr/local/lib/pgtoken/pgtoken.so:*) ;;
            *) export LD_PRELOAD="/usr/local/lib/pgtoken/pgtoken.so${LD_PRELOAD:+:$LD_PRELOAD}" ;;
        esac ;;
esac
CHECK
chown --reference="$home" "$home/.bashrc.d" "$home/.bashrc.d/130_pgtoken.sh"
