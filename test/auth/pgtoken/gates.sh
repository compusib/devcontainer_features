#!/usr/bin/env bash
# The gates of pgtoken. Run after `make -C src/auth/pgtoken`, in a shell that has the ssh agent:
#   bash test/auth/pgtoken/gates.sh [I M L ...]
#   I  inert   the loader, preloaded into programs that are no PostgreSQL 18 client, changes nothing
#   M  mint    a token from a throwaway Hydra, for an assert signed by the agent's own key. Needs docker.
#   L  login   psql logs in to a throwaway PostgreSQL 18 server: on libpq 19 with nothing preloaded, on libpq 18
#              through the loader. Needs docker, and a daemon that sees this machine's files: the clients are
#              containers, and get the agent's socket.
# PGTOKEN_DIR is the directory of the three libraries (default: what `make` built, src/auth/pgtoken/build).
# PGTOKEN_CLIENT_PLATFORM is the platform of gate L's clients, when it is not the machine's own: the other
# architecture's libraries are tried under emulation with
#   PGTOKEN_DIR=src/auth/pgtoken/dist/linux_amd64 PGTOKEN_CLIENT_PLATFORM=linux/amd64 bash test/auth/pgtoken/gates.sh L
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); src=$here/../../../src/auth/pgtoken; B=${PGTOKEN_DIR:-$src/build}; T=$(mktemp -d); rc=0
shim=$B/pgtoken.so; module=$B/libpq-oauth.so; oauth=$B/pgtoken-oauth.so
cleanup() { rm -f "$T"/*; rmdir "$T"; }
trap cleanup EXIT
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1: $(sed -E 's/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/<a token>/g' <<<"$2")"; rc=1; }
is() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$3', got '$2'"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1" "expected '$3' in '$(cut -c1-400 <<<"$2")'" ;; esac; }

json() { curl -s -H 'content-type: application/json' "$@"; }
# A payload segment of a token (base64url) on standard input: its claims, as JSON.
payload() { tr '_-' '/+' | { read -r p; while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done; echo "$p"; } | base64 -d 2>/dev/null; }
# The throwaway Hydra whose admin API is at $1 gets the trust for the agent's key, the public client psql, and the
# client host, which proves itself with a key of its own ($T/host.test), published as the gateway names it: the
# file's name, a space, the key's thumbprint. $T/stranger is a key nobody published.
hydra_knows() {
  ssh-jwt jwk | jq '{issuer: "dev@test", allow_any_subject: true, scope: ["pg"], expires_at: "2099-01-01T00:00:00Z", jwk: (if type == "array" then .[0] else . end)}' \
    | json -X POST "$1/admin/trust/grants/jwt-bearer/issuers" -d @- | jq -e .id >/dev/null || fail "the trust for the agent's key" "not registered"
  json -X POST "$1/admin/clients" -d '{"client_id": "psql", "client_name": "psql", "grant_types": ["urn:ietf:params:oauth:grant-type:jwt-bearer"], "token_endpoint_auth_method": "none", "scope": "pg", "audience": ["admin.test"]}' >/dev/null
  openssl genrsa -out "$T/host.test" 2048 2>/dev/null; openssl genrsa -out "$T/stranger" 2048 2>/dev/null
  python3 -c 'import base64, hashlib, json, subprocess, sys
n = bytes.fromhex(subprocess.run(["openssl", "rsa", "-in", sys.argv[1], "-noout", "-modulus"], capture_output=True, text=True).stdout.strip().split("=", 1)[1])
b = lambda x: base64.urlsafe_b64encode(x).rstrip(b"=").decode()
thumb = b(hashlib.sha256(json.dumps({"e": "AQAB", "kty": "RSA", "n": b(n)}, separators=(",", ":"), sort_keys=True).encode()).digest())
print(json.dumps({"kty": "RSA", "alg": "RS512", "use": "sig", "kid": "host.test " + thumb, "n": b(n), "e": "AQAB"}))' "$T/host.test" > "$T/host.jwk"
  jq -n --slurpfile key "$T/host.jwk" '{client_id: "host", client_name: "host.test_private_key_jwt", grant_types: ["urn:ietf:params:oauth:grant-type:jwt-bearer"],
      token_endpoint_auth_method: "private_key_jwt", token_endpoint_auth_signing_alg: "RS512", jwks: {keys: $key}, audience: ["admin.test"]}' \
    | json -X POST "$1/admin/clients" -d @- | jq -e '.client_id == "host"' >/dev/null || fail "the client with a key" "not registered"
}

gate_I() {
  is "ls runs" "$(LD_PRELOAD=$shim ls -d / 2>&1)" "/"
  is "no thread is added to a program" "$(LD_PRELOAD=$shim sh -c 'ls /proc/self/task | wc -l')" "1"
  is "a shell forks and goes on" "$(LD_PRELOAD=$shim bash -c '(echo sub) | cat; (true); echo ok' 2>&1 | tr '\n' ' ')" "sub ok "
  is "python forks without a word" "$(LD_PRELOAD=$shim python3 -c 'import os
pid = os.fork()
if pid == 0: os._exit(0)
os.waitpid(pid, 0); print("ok")' 2>&1)" "ok"
  is "it exports no symbol: no function of a program is replaced" "$(objdump -T "$shim" | awk '$2 == "g" && $4 != "*UND*"' | wc -l)" "0"
  local old; old=$(command -v psql || true)
  if [ -n "$old" ] && ! grep -q PQsetAuthDataHook "$(ldd "$(readlink -f "$old")" 2>/dev/null | awk '/libpq/ {print $3}')" 2>/dev/null; then
    has "an older psql connects as before" "$(LD_PRELOAD=$shim PGCONNECT_TIMEOUT=2 "$old" -h 127.0.0.1 -p 9 -U x -d x -w -c 'select 1' 2>&1)" "Connection refused"
  fi
}

gate_M() {
  command -v docker >/dev/null && command -v ssh-jwt >/dev/null && [ -S "${SSH_AUTH_SOCK:-}" ] || { fail "docker, ssh-jwt and an ssh agent" "one is missing"; return; }
  gcc -o "$T/mint-try" "$here/mint-try.c" || { fail "mint-try" "does not build"; return; }
  local net=pgtoken-$$ me; me=$(hostname); local h=hydra-pgtoken-$$ H A D inner publish=()
  if docker inspect "$me" >/dev/null 2>&1; then   # this shell's container is one of the daemon's: it joins the test network
    H=http://$h:4444; A=http://$h:4445; inner=http://inner-$h:4444
  else                                            # the daemon is this container's own (docker-in-docker): Hydra's ports, here
    H=http://localhost:4444; A=http://localhost:4445; inner=http://127.0.0.1:4444; me=; publish=(-p 127.0.0.1:4444:4444 -p 127.0.0.1:4445:4445)
  fi
  D=$H/.well-known/openid-configuration
  down() { [ -z "$me" ] || docker network disconnect "$net" "$me" >/dev/null 2>&1; docker rm -f "$h" >/dev/null 2>&1; docker network rm "$net" >/dev/null 2>&1; }
  docker network create "$net" >/dev/null
  docker run -d --network "$net" --network-alias "$h" --network-alias "inner-$h" "${publish[@]}" --name "$h" -e DSN=memory -e SECRETS_SYSTEM=a-secret-of-this-test-alone-0123456789 \
    -e URLS_SELF_ISSUER="$H" -e STRATEGIES_ACCESS_TOKEN=jwt "${HYDRA_IMG:-oryd/hydra:v26.2.0}" serve all --dev >/dev/null
  [ -z "$me" ] || docker network connect "$net" "$me" || { fail "this container on the test network" "docker network connect"; down; return; }
  for _ in $(seq 1 60); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$H/health/ready")" = 200 ] && break; sleep 0.5; done
  hydra_knows "$A"
  claims() { cut -d. -f2 | payload | jq -r '"iss=\(.iss) sub=\(.sub) scope=\(.scp | join(" ")) client=\(.client_id) audience=\(.aud | index("admin.test") != null)"'; }
  local base=(discovery="$D" scope=pg subject=dev@test allow_http=1)
  m() { "$T/mint-try" "$oauth" "${base[@]}" "$@" 2>&1; }   # a name given again replaces the one above
  is  "a public client: a token, with the audience" "$(m client_id=psql audience=admin.test | claims)" "iss=$H sub=dev@test scope=pg client=psql audience=true"
  is  "without an audience, none"                   "$(m client_id=psql | claims)"                     "iss=$H sub=dev@test scope=pg client=psql audience=false"
  is  "the server reached at another address"       "$(m client_id=psql server="$inner" | claims)"     "iss=$H sub=dev@test scope=pg client=psql audience=false"
  has "a server that is another issuer"             "$(m client_id=psql discovery="$inner/.well-known/openid-configuration" server="$H")" "the connection trusts"
  has "a server that does not answer"               "$(m client_id=psql server=http://127.0.0.1:9)"    "connection refused"
  has "a client the issuer does not know"           "$(m client_id=nobody)"                            "invalid_client"
  has "a scope outside the key's trust"             "$(m client_id=psql scope=admin)"                  "invalid_scope"
  has "a subject the key has no trust under"        "$(m client_id=psql subject=other@test)"           "invalid_grant"
  has "an issuer without TLS, not in a test"        "$(m client_id=psql allow_http=0)"                 "not an https address"
  has "an address that is no discovery one"         "$(m client_id=psql discovery="$H/elsewhere")"     "not an OpenID one"
  has "no ssh agent"                                "$(SSH_AUTH_SOCK=/nonexistent m client_id=psql)"   "the ssh agent"
  is  "a client that proves itself with its key"    "$(m client_id=host client_key_file="$T/host.test" audience=admin.test | claims)" "iss=$H sub=dev@test scope=pg client=host audience=true"
  has "that client with another key"                "$(m client_id=host client_key_file="$T/stranger" client_key_id="$(jq -r .kid "$T/host.jwk")")" "invalid_client"
  has "that client without its key"                 "$(m client_id=host)"                              "invalid_client"
  has "a key file that is not there"                "$(m client_id=host client_key_file="$T/none")"    "the client's key"
  down
}

gate_L() {
  command -v docker >/dev/null && command -v ssh-jwt >/dev/null && [ -S "${SSH_AUTH_SOCK:-}" ] || { fail "docker, ssh-jwt and an ssh agent" "one is missing"; return; }
  local net=pgtoken-L-$$ h=hydra-L-$$ pg=pg-L-$$ c19=libpq19-L-$$ c18=libpq18-L-$$ me H A P inner c n
  me=$(hostname); H=http://$h:4444; inner=http://inner-$h:4444
  local password=a-password-of-this-test-alone loader=/usr/local/lib/pgtoken/pgtoken.so
  down() { [ -z "$me" ] || docker network disconnect "$net" "$me" >/dev/null 2>&1; docker rm -f "$c19" "$c18" "$pg" "$h" >/dev/null 2>&1; docker network rm "$net" >/dev/null 2>&1; }

  # The server: a PostgreSQL 18 that asks the role `dev` for a bearer token (server/), and `pw` for its password.
  docker build -q -t pgtoken-gate-server "$here/server" >/dev/null || { fail "the server's image" "does not build"; return; }
  docker network create "$net" >/dev/null
  # Hydra: the clients reach it by its name on the network. From here its two ports are reached as in gate M: A is
  # the admin API, P the public one, which is asked only whether it is ready.
  docker run -d --network "$net" --network-alias "$h" --network-alias "inner-$h" -p 127.0.0.1::4444 -p 127.0.0.1::4445 --name "$h" -e DSN=memory -e SECRETS_SYSTEM=a-secret-of-this-test-alone-0123456789 \
    -e URLS_SELF_ISSUER="$H" -e STRATEGIES_ACCESS_TOKEN=jwt "${HYDRA_IMG:-oryd/hydra:v26.2.0}" serve all --dev >/dev/null
  if docker inspect "$me" >/dev/null 2>&1; then
    docker network connect "$net" "$me" || { fail "this container on the test network" "docker network connect"; down; return; }
    A=http://$h:4445; P=$H
  else
    me=; A=http://127.0.0.1:$(docker port "$h" 4445/tcp | sed 's/.*://'); P=http://127.0.0.1:$(docker port "$h" 4444/tcp | sed 's/.*://')
  fi
  docker run -d --network "$net" --network-alias "$pg" --name "$pg" -e POSTGRES_PASSWORD="$password" -e OAUTH_ISSUER="$H" pgtoken-gate-server >/dev/null
  for _ in $(seq 1 120); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$A/health/ready")$(curl -s -o /dev/null -w '%{http_code}' "$P/.well-known/openid-configuration")" = 200200 ] && break; sleep 0.5
  done
  hydra_knows "$A"
  for _ in $(seq 1 120); do docker exec "$pg" pg_isready -q -h 127.0.0.1 && break; sleep 0.5; done

  # The clients: pgtoken is installed in each as the feature installs it. Nothing here sets LD_PRELOAD or a
  # library path. libpq 19 takes an address without TLS on `UNSAFE:http`; libpq 18 knows `UNSAFE` alone.
  printf '[pg]\nhost=%s\ndbname=postgres\nuser=dev\noauth_issuer=%s\noauth_client_id=psql\n[jwt]\nhost=%s\ndbname=postgres\nuser=dev\noauth_issuer=%s\noauth_client_id=jwt_instead_of_client_id\n' \
    "$pg" "$H" "$pg" "$H" > "$T/services"
  echo host > "$T/client"   # a file that holds the client's id
  client() {   # client <name> <image> <PGOAUTHDEBUG>
    docker run -d ${PGTOKEN_CLIENT_PLATFORM:+--platform "$PGTOKEN_CLIENT_PLATFORM"} --network "$net" --name "$1" -v "$SSH_AUTH_SOCK":/agent -e SSH_AUTH_SOCK=/agent -e PGOAUTHDEBUG="$3" --entrypoint sleep "$2" infinity >/dev/null \
      && docker cp -q "$B" "$1":/built && docker cp -q "$src/install-pgtoken.sh" "$1":/install-pgtoken.sh && docker cp -q "$T/services" "$1":/root/.pg_service.conf \
      && docker cp -q "$T/host.test" "$1":/host.test && docker cp -q "$T/client" "$1":/client \
      && docker exec "$1" bash /install-pgtoken.sh /built /root
  }
  client "$c19" "${LIBPQ19_IMG:-postgres:18-trixie}" UNSAFE:http || fail "pgtoken in the libpq 19 client" "not installed"
  client "$c18" "${LIBPQ18_IMG:-postgres:18.0-bookworm}" UNSAFE || fail "pgtoken in the libpq 18 client" "not installed"
  libpq() { docker exec "$1" sh -c 'readlink -f /usr/lib/*/libpq.so.5' 2>&1 | sed 's/.*libpq\.so\.5\.//'; }
  if [ "$(libpq "$c19")" -ge 19 ] 2>/dev/null; then pass "the first client's libpq is 19 or newer"; else fail "the first client's libpq" "is $(libpq "$c19"), not 19 or newer"; fi
  is "the second client's libpq is 18" "$(libpq "$c18")" "18"

  # q <client> [<VAR=value>...] -- <connection string>: who the server says has logged in, asked in a shell of the
  # client that has read ~/.bashrc.d, as a developer's has.
  q() { local at=$1 e=(); shift; while [ "$1" != -- ]; do e+=(-e "$1"); shift; done
        docker exec -e PGCONNECT_TIMEOUT=10 -e PG_OAUTH_SUBJECT=dev@test "${e[@]}" "$at" bash -c '. ~/.bashrc.d/130_pgtoken.sh; exec psql -XAtc "select system_user" "$0"' "$2" 2>&1; }
  preloaded() { docker exec "$1" bash -c '. ~/.bashrc.d/130_pgtoken.sh; echo "${LD_PRELOAD:-}"' 2>&1; }
  # An OAuth login is shown by the claims of the token the server got (server/validator.c). Anything else: as it is.
  seen() { local out; out=$(cat); case "$out" in oauth:*) payload <<<"${out#oauth:}" | jq -r '"iss=\(.iss) sub=\(.sub) client=\(.client_id)"' ;; *) echo "$out" ;; esac; }
  local jwt given="iss=null sub=given@test client=null" minted="iss=$H sub=dev@test client=psql" hosts="iss=$H sub=dev@test client=host"
  jwt="h.$(printf '{"sub":"given@test"}' | base64 | tr '+/' '-_' | tr -d '=').s"

  # With no JWT and no ssh agent there is nothing to sign with. PostgreSQL's own module is not installed yet.
  for c in "$c19" "$c18"; do
    n=${c%%-*}
    has "L11 $n, no JWT and no ssh agent, and no other module: the reason is said" "$(q "$c" SSH_AUTH_SOCK= -- service=pg)" "the ssh agent"
  done
  # From here on PostgreSQL's own module is installed in both clients, in the version of their libpq: ours is
  # still the one that is found, and falls back to it where it has nothing to sign with.
  docker exec "$c19" sh -c 'apt-get update -qq && apt-get install -y -qq --no-install-recommends libpq-oauth' >/dev/null 2>&1 \
    && docker exec "$c18" sh -c 'apt-get update -qq && v=$(apt-cache madison libpq-oauth | awk "\$3 ~ /^18\\./ {print \$3; exit}") && apt-get install -y -qq --no-install-recommends "libpq-oauth=$v" "libpq5=$v"' >/dev/null 2>&1 \
    || fail "PostgreSQL's own module in the clients" "not installed"
  if [ "$(libpq "$c19")" -ge 19 ] 2>/dev/null; then pass "the first client's libpq is still 19 or newer"; else fail "the first client's libpq" "is $(libpq "$c19") now"; fi
  is  "the second client's libpq is still 18"                    "$(libpq "$c18")" "18"
  has "libpq 19: PostgreSQL's own module is there"               "$(docker exec "$c19" sh -c 'ls /usr/lib/*/libpq-oauth.so' 2>&1)" "/libpq-oauth.so"
  has "libpq 18: PostgreSQL's own module is there"               "$(docker exec "$c18" sh -c 'ls /usr/lib/*/libpq-oauth-18.so' 2>&1)" "/libpq-oauth-18.so"
  is  "libpq 19: ours is the one the linker finds"               "$(docker exec "$c19" sh -c 'ldconfig -p | awk "/libpq-oauth.so / {print \$NF; exit}"' 2>&1)" "/usr/local/lib/pgtoken/libpq-oauth.so"

  is  "L1 libpq 19: nothing is preloaded"                        "$(preloaded "$c19")" ""
  is  "L1 libpq 19, a JWT is given: psql logs in with it"        "$(q "$c19" PG_OAUTH_TOKEN="$jwt" -- service=jwt | seen)" "$given"
  is  "L2 libpq 19, none is given: psql logs in with a minted one" "$(q "$c19" PGSERVICE=pg -- "" | seen)" "$minted"
  is  "L3 libpq 18: the check has preloaded the loader"          "$(preloaded "$c18")" "$loader"
  is  "L3 libpq 18: read twice, the loader is there once"        "$(docker exec "$c18" bash -c '. ~/.bashrc.d/130_pgtoken.sh; . ~/.bashrc.d/130_pgtoken.sh; echo "$LD_PRELOAD"' 2>&1)" "$loader"
  is  "L3 libpq 18, a JWT is given: psql logs in with it"        "$(q "$c18" PG_OAUTH_TOKEN="$jwt" -- service=jwt | seen)" "$given"
  is  "L4 libpq 18, none is given: psql logs in with a minted one" "$(q "$c18" PGSERVICE=pg -- "" | seen)" "$minted"
  is  "L5 libpq 19 with the loader preloaded all the same"       "$(q "$c19" LD_PRELOAD="$loader" PG_OAUTH_TOKEN="$jwt" -- service=jwt | seen)" "$given"
  is  "L6 a JWT is given and there is no mint to load"           "$(q "$c19" PG_OAUTH_LIBRARY=/nonexistent PG_OAUTH_TOKEN="$jwt" -- service=jwt | seen)" "$given"
  has "L6 none is given and there is no mint to load"            "$(q "$c19" PG_OAUTH_LIBRARY=/nonexistent -- service=pg)" "/nonexistent"
  for c in "$c19" "$c18"; do
    n=${c%%-*}
    has "L7 $n, a subject without trust: Hydra's refusal"        "$(q "$c" PG_OAUTH_SUBJECT=other@test -- service=pg)" "invalid_grant"
    is  "L8 $n, a role with a password logs in with it"          "$(q "$c" PGPASSWORD="$password" -- "service=pg user=pw")" "scram-sha-256:pw"
    has "L9 $n, the service's client is the one Hydra is asked as" "$(q "$c" -- service=jwt)" "invalid_client"
    is  "L9 $n, the connection string's client wins over it"     "$(q "$c" -- "service=jwt oauth_client_id=psql" | seen)" "$minted"
    is  "L9 $n, PGSERVICE and PGUSER lose to the connection string" "$(q "$c" PGSERVICE=jwt PGUSER=pw -- "service=pg user=dev" | seen)" "$minted"
    is  "L10 $n, PG_OAUTH_SERVER names another address of Hydra" "$(q "$c" PG_OAUTH_SERVER="$inner" -- service=pg | seen)" "$minted"
    has "L10 $n, PG_OAUTH_SERVER names an address nobody is at"  "$(q "$c" PG_OAUTH_SERVER=http://127.0.0.1:9 -- service=pg)" "127.0.0.1:9"
    is  "L12 $n, the client and its key from the environment"    "$(q "$c" PG_OAUTH_CLIENT_ID=host PG_OAUTH_CLIENT_KEY_FILE=/host.test -- "service=pg oauth_client_id=from_the_environment" | seen)" "$hosts"
    is  "L12 $n, the client's id from a file"                    "$(q "$c" PG_OAUTH_CLIENT_ID_FILE=/client PG_OAUTH_CLIENT_KEY_FILE=/host.test -- "service=pg oauth_client_id=from_the_environment" | seen)" "$hosts"
    has "L12 $n, that client without its key: Hydra's refusal"   "$(q "$c" PG_OAUTH_CLIENT_ID=host -- "service=pg oauth_client_id=from_the_environment")" "invalid_client"
    has "L12 $n, the environment names no client"                "$(q "$c" -- "service=pg oauth_client_id=from_the_environment")" "PG_OAUTH_CLIENT_ID"
    is  "L12 $n, an id the connection names stands"              "$(q "$c" PG_OAUTH_CLIENT_ID=host -- service=pg | seen)" "$minted"
  done
  has "L7 libpq 18: the loader is the one that says it"          "$(q "$c18" PG_OAUTH_SUBJECT=other@test -- service=pg)" "pgtoken: "
  for c in "$c19" "$c18"; do
    n=${c%%-*}
    has "L11 $n, no JWT and no ssh agent: PostgreSQL's own flow is started" "$(q "$c" SSH_AUTH_SOCK= -- service=pg)" "device authorization"
    has "L11 $n, no JWT and no ssh agent: and why is said"       "$(q "$c" SSH_AUTH_SOCK= -- service=pg)" "pgtoken: the ssh agent"
  done
  has "L11 libpq 19 with the loader preloaded all the same"      "$(q "$c19" LD_PRELOAD="$loader" SSH_AUTH_SOCK= -- service=pg)" "device authorization"
  down
}

[ -f "$shim" ] && [ -f "$module" ] && [ -f "$oauth" ] || { echo "build first: make -C src/auth/pgtoken"; exit 1; }
for g in "${@:-I M L}"; do for one in $g; do echo "gate $one"; "gate_$one"; done; done
[ $rc = 0 ] && echo "all gates passed" || echo "FAILED"
exit $rc
