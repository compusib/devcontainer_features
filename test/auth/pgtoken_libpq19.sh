#!/bin/bash
# Scenario test: a container whose PostgreSQL client runs on libpq 19 (what PGDG gives a PostgreSQL 18 client
# today). libpq loads pgtoken's module by itself there, so nothing is preloaded. The logins themselves are gate L's
# (pgtoken/gates.sh), which installs pgtoken with the script the feature installs it with.
set -e

source dev-container-features-test-lib

check "this container's libpq is 19 or newer" \
    bash -c 'v=$(readlink -f /usr/lib/*/libpq.so.5); [ "${v##*.}" -ge 19 ]'

check "the linker finds pgtoken's module by the name libpq 19 asks for" \
    bash -c '[ "$(/sbin/ldconfig -p | awk "/libpq-oauth.so / {print \$NF; exit}")" = /usr/local/lib/pgtoken/libpq-oauth.so ]'

check "the mint is beside it" test -f /usr/local/lib/pgtoken/pgtoken-oauth.so

check "a shell of the user preloads nothing" bash -ic '[ -z "${LD_PRELOAD:-}" ]'

reportResults
