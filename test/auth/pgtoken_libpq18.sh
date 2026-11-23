#!/bin/bash
# Scenario test: a container whose PostgreSQL client runs on libpq 18, which cannot load pgtoken's module itself.
# A shell of the user preloads the loader there, and the loader changes nothing in a program that is no
# PostgreSQL client (gate I, against the installed file). The logins themselves are gate L's.
set -e

source dev-container-features-test-lib

check "this container's libpq is 18" \
    bash -c 'v=$(readlink -f /usr/lib/*/libpq.so.5); [ "${v##*.}" = 18 ]'

check "a shell of the user preloads the loader" \
    bash -ic '[ "$LD_PRELOAD" = /usr/local/lib/pgtoken/pgtoken.so ]'

check "the module and the mint are there for it" \
    test -f /usr/local/lib/pgtoken/libpq-oauth.so -a -f /usr/local/lib/pgtoken/pgtoken-oauth.so

# What gate I uses and the image has not: python, and objdump.
apt-get update > /dev/null
apt-get install -y --no-install-recommends python3 binutils > /dev/null

check "gate I: preloaded, the loader changes nothing in a program that is no PostgreSQL 18 client" \
    env PGTOKEN_DIR=/usr/local/lib/pgtoken bash pgtoken/gates.sh I

reportResults
