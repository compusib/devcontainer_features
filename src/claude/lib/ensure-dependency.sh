#!/bin/bash
#
# Generic apt dependency installer for the 'claude' feature.
#
# Runtime dependencies are best installed in the devcontainer's Dockerfile (baked
# into the image) so they don't need re-installing on every rebuild and so the
# build is reproducible. If one is missing we install it here as a fallback and
# warn, printing the Dockerfile line that would bake it in.

# Path of the keyring a third-party repo's packages are verified against.
apt_repo_keyring() { echo "/etc/apt/keyrings/${1}.gpg"; }

# register_apt_repo <name> <key-url> <repo-spec>
# Register a third-party apt repository (modern signed-by style) so apt can
# install from it. <repo-spec> is the source line minus its [signed-by] options,
# as "<url> <suite> <component>" (e.g. "https://cli.github.com/packages stable main").
register_apt_repo() {
    local name="$1" key_url="$2" repo_spec="$3"
    local keyring; keyring="$(apt_repo_keyring "$name")"

    apt-get update -y
    apt-get install -y --no-install-recommends curl ca-certificates
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$key_url" -o "$keyring"
    chmod go+r "$keyring"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] ${repo_spec}" \
        > "/etc/apt/sources.list.d/${name}.list"
}

# print_dockerfile_hint <command> <apt-package> [key-url] [repo-spec]
# Print the Dockerfile RUN line that reproduces this dependency's install,
# prepending the repo-registration steps when a third-party repo is supplied.
print_dockerfile_hint() {
    local cmd="$1" apt_pkg="$2" key_url="${3:-}" repo_spec="${4:-}"
    local keyring; keyring="$(apt_repo_keyring "$cmd")"
    local -a steps=()
    if [[ -n "$key_url" ]]; then
        steps+=(
            "install -m 0755 -d /etc/apt/keyrings"
            "curl -fsSL ${key_url} -o ${keyring}"
            "chmod go+r ${keyring}"
            "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=${keyring}] ${repo_spec}\" > /etc/apt/sources.list.d/${cmd}.list"
        )
    fi
    steps+=(
        "apt-get update"
        "apt-get install -y --no-install-recommends ${apt_pkg}"
        "rm -rf /var/lib/apt/lists/*"
    )

    local i
    for i in "${!steps[@]}"; do
        if [[ "$i" -eq 0 ]]; then
            printf '         RUN %s' "${steps[i]}"
        else
            printf ' \\\n          && %s' "${steps[i]}"
        fi
    done
    printf '\n'
}

# ensure_dependency <command> <apt-package> [key-url] [repo-spec]
# Orchestrates the helpers: no-op when <command> is present; otherwise warn,
# print the Dockerfile hint, then install (registering a third-party repo first
# when [key-url]/[repo-spec] are given — neither can be derived from the other).
ensure_dependency() {
    local cmd="$1" apt_pkg="$2" key_url="${3:-}" repo_spec="${4:-}"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ '${cmd}' already present, nothing to do."
        return 0
    fi

    echo "⚠️  '${cmd}' not found — installing it now as a fallback."
    echo "    👉 Better to bake it into your devcontainer's Dockerfile so it is"
    echo "       part of the image. Add the following to your Dockerfile:"
    echo ""
    print_dockerfile_hint "$cmd" "$apt_pkg" "$key_url" "$repo_spec"
    echo ""

    if ! command -v apt-get >/dev/null 2>&1; then
        echo "❌ apt-get not available; cannot auto-install '${cmd}'. Please install it manually."
        return 1
    fi

    [[ -n "$key_url" ]] && register_apt_repo "$cmd" "$key_url" "$repo_spec"
    apt-get update -y
    apt-get install -y --no-install-recommends "${apt_pkg}"
    rm -rf /var/lib/apt/lists/*
}
