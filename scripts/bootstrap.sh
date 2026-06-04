#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS=$(uname -s)

echo "==> Laptop setup bootstrap"
echo "    OS: $OS"
echo "    Repo: $REPO_DIR"
echo ""

# Require git identity before doing anything
if [ -z "${GIT_USER_NAME:-}" ] || [ -z "${GIT_USER_EMAIL:-}" ]; then
    echo "Error: GIT_USER_NAME and GIT_USER_EMAIL must be exported before running bootstrap."
    echo ""
    echo "  export GIT_USER_NAME='Your Name'"
    echo "  export GIT_USER_EMAIL='you@example.com'"
    echo "  make bootstrap"
    exit 1
fi

# Install Nix via Determinate Systems installer if not present
if ! command -v nix &>/dev/null; then
    echo "==> Installing Nix (Determinate Systems)..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm

    # Source Nix for this shell session
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        # shellcheck disable=SC1091
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
else
    echo "==> Nix already installed: $(nix --version)"
fi

# Apply home-manager configuration (uses version pinned in flake.lock after first run)
echo "==> Applying home-manager configuration..."
nix run github:nix-community/home-manager -- switch \
    --flake "${REPO_DIR}#default" \
    --impure

# Install TPM (Tmux Plugin Manager) if not present
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "==> Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Install claude-code via npm (node is on PATH after home-manager activation)
if ! command -v claude &>/dev/null; then
    echo "==> Installing claude-code via npm..."
    npm install -g @anthropic-ai/claude-code
else
    echo "==> claude-code already installed: $(claude --version 2>/dev/null || echo 'unknown')"
fi

echo ""

# Platform-specific post-install notes
if [ "$OS" = "Darwin" ]; then
    echo "==> macOS: Docker daemon runs via colima."
    echo "    Start manually:      colima start"
    echo "    Start at login:      colima start (add to ~/.zprofile)"
    echo ""
    echo "==> macOS: Ghostty and Rectangle are installed."
    echo "    Launch them from /Applications or Spotlight."
else
    echo "==> Linux: Docker daemon requires a system service."
    echo "    Enable now:          sudo systemctl enable --now docker"
    echo "    Add user to group:   sudo usermod -aG docker \$USER  (re-login required)"
fi

echo ""
echo "==> Bootstrap complete! Open a new terminal to activate your environment."
