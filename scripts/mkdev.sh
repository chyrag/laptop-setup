#!/usr/bin/env bash
# mkdev.sh — create or extend a per-project Nix devShell
#
# Usage:
#   mkdev.sh <type> <name>   — create ~/work/<name> with a <type> devShell
#   mkdev.sh add <type>      — add a <type> devShell to the current project
#
# Supported types: go, python, rust, ruby, ansible, terraform, opentofu

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${HOME}/work"
VALID_TYPES="go python rust ruby ansible terraform opentofu"

usage() {
    echo "Usage:"
    echo "  mkdev.sh <type> <name>   — new project at ~/work/<name>"
    echo "  mkdev.sh add <type>      — add toolchain to current project"
    echo ""
    echo "Types: ${VALID_TYPES}"
    exit 1
}

validate_type() {
    local type="$1"
    for t in $VALID_TYPES; do
        [ "$t" = "$type" ] && return 0
    done
    echo "Error: unknown type '${type}'. Valid types: ${VALID_TYPES}"
    exit 1
}

cmd_new() {
    local type="$1"
    local name="$2"
    local project_dir="${WORK_DIR}/${name}"

    validate_type "$type"

    if [ -e "$project_dir" ]; then
        echo "Error: ${project_dir} already exists."
        exit 1
    fi

    echo "==> Creating ${project_dir}"
    mkdir -p "$project_dir"
    cd "$project_dir"

    echo "==> Initialising ${type} devShell"
    nix flake init -t "${REPO_DIR}#${type}"

    echo "==> Configuring direnv"
    echo "use flake" > .envrc
    direnv allow

    echo ""
    echo "Done. cd into the project and the devShell activates automatically:"
    echo ""
    echo "  cd ${project_dir}"
    echo ""
}

cmd_add() {
    local type="$1"
    local project_dir="${PWD}"

    validate_type "$type"

    if [ ! -f "${project_dir}/flake.nix" ]; then
        echo "Error: no flake.nix found in ${project_dir}."
        echo "Run mkdev.sh from inside an existing project directory."
        exit 1
    fi

    echo "==> Merging ${type} packages into existing flake.nix"

    # Extract the packages list from the template for this type
    local template_flake="${REPO_DIR}/templates/${type}/flake.nix"
    if [ ! -f "$template_flake" ]; then
        echo "Error: template not found at ${template_flake}"
        exit 1
    fi

    # Extract package names from the template (lines matching pkgs.<name>)
    local new_pkgs
    new_pkgs=$(grep -oP 'pkgs\.\K[a-zA-Z0-9_-]+' "$template_flake" | sort -u | tr '\n' ' ')

    echo ""
    echo "Packages from the ${type} template:"
    echo "  ${new_pkgs}"
    echo ""
    echo "Add these to the 'packages' list in your flake.nix:"
    echo ""
    grep -oP 'pkgs\.[a-zA-Z0-9_-]+' "$template_flake" | sort -u | sed 's/^/  /'
    echo ""
    echo "Then run: direnv reload"
    echo ""
    echo "Tip: for a fully-merged multi-toolchain flake, see the template at:"
    echo "  ${template_flake}"
}

# ── Argument dispatch ─────────────────────────────────────────────────────────

[ $# -lt 1 ] && usage

case "$1" in
    add)
        [ $# -lt 2 ] && { echo "Error: mkdev.sh add <type>"; exit 1; }
        cmd_add "$2"
        ;;
    -h|--help)
        usage
        ;;
    *)
        [ $# -lt 2 ] && { echo "Error: mkdev.sh <type> <name>"; exit 1; }
        cmd_new "$1" "$2"
        ;;
esac
