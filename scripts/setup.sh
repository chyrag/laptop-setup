#!/usr/bin/env bash
# Non-Nix setup: installs packages via Homebrew (macOS) or apt (Linux),
# then copies dotfiles from the repo's dotfiles/ directory.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS=$(uname -s)

echo "==> Laptop setup (brew/apt)"
echo "    OS: $OS"
echo "    Repo: $REPO_DIR"
echo ""

if [ -z "${GIT_USER_NAME:-}" ] || [ -z "${GIT_USER_EMAIL:-}" ]; then
    echo "Error: GIT_USER_NAME and GIT_USER_EMAIL must be exported before running setup."
    echo ""
    echo "  export GIT_USER_NAME='Your Name'"
    echo "  export GIT_USER_EMAIL='you@example.com'"
    echo "  make setup"
    exit 1
fi

mkdir -p "$HOME/.local/bin"

# ─────────────────────────────────────────────────────────────────────────────
# macOS: Homebrew
# ─────────────────────────────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then

    if ! command -v brew &>/dev/null; then
        echo "==> Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Load brew into the current shell session
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    echo "==> Installing packages via Homebrew..."
    brew bundle --file="$REPO_DIR/dotfiles/brew/Brewfile"

    BREW_PREFIX="$(brew --prefix)"

    echo "==> Writing ~/.zshrc..."
    # Build a complete zshrc: brew env + plugins + tool hooks + user config.
    # The heredoc delimiter is single-quoted so $(...) inside is NOT expanded now —
    # it runs at shell startup instead.
    {
        cat << 'HEADER'
# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=524288
SAVEHIST=524288
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY

# Plugins (installed via brew)
BREW_PREFIX="$(brew --prefix)"
[[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$BREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] && \
    source "$BREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"

# Completions
autoload -Uz compinit && compinit

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^R'   history-incremental-search-backward
bindkey '^ '   autosuggest-accept
zstyle ':completion:*' menu yes select

# Tool hooks
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# User config
HEADER
        cat "$REPO_DIR/dotfiles/zsh/zshrc"
    } > "$HOME/.zshrc"

# ─────────────────────────────────────────────────────────────────────────────
# Linux: apt + GitHub release binaries
# ─────────────────────────────────────────────────────────────────────────────
else

    echo "==> Installing apt packages..."
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        tmux emacs bat fd-find fzf ripgrep jq notmuch isync direnv \
        zsh zsh-autosuggestions zsh-syntax-highlighting \
        zsh-history-substring-search git curl wget gpg ca-certificates

    # Debian installs these as 'batcat' and 'fdfind' to avoid name conflicts
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi

    # gh (GitHub CLI)
    if ! command -v gh &>/dev/null; then
        echo "==> Installing gh..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y gh
    fi

    # eza (not in Debian bookworm main)
    if ! command -v eza &>/dev/null; then
        echo "==> Installing eza..."
        EZA_VER=$(curl -sSf https://api.github.com/repos/eza-community/eza/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        mkdir -p /tmp/eza-install
        curl -sSfLo /tmp/eza-install/eza.tar.gz \
            "https://github.com/eza-community/eza/releases/download/v${EZA_VER}/eza_x86_64-unknown-linux-gnu.tar.gz"
        tar xzf /tmp/eza-install/eza.tar.gz -C /tmp/eza-install
        mv /tmp/eza-install/eza "$HOME/.local/bin/eza"
        rm -rf /tmp/eza-install
    fi

    # yq
    if ! command -v yq &>/dev/null; then
        echo "==> Installing yq..."
        YQ_VER=$(curl -sSf https://api.github.com/repos/mikefarah/yq/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        curl -sSfLo "$HOME/.local/bin/yq" \
            "https://github.com/mikefarah/yq/releases/download/v${YQ_VER}/yq_linux_amd64"
        chmod +x "$HOME/.local/bin/yq"
    fi

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        echo "==> Installing zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # starship
    if ! command -v starship &>/dev/null; then
        echo "==> Installing starship..."
        curl -sSfL https://starship.rs/install.sh | sh -s -- -y
    fi

    # kubecolor
    if ! command -v kubecolor &>/dev/null; then
        echo "==> Installing kubecolor..."
        KC_VER=$(curl -sSf https://api.github.com/repos/kubecolor/kubecolor/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        mkdir -p /tmp/kc-install
        curl -sSfLo /tmp/kc-install/kubecolor.tar.gz \
            "https://github.com/kubecolor/kubecolor/releases/download/v${KC_VER}/kubecolor_${KC_VER}_linux_amd64.tar.gz"
        tar xzf /tmp/kc-install/kubecolor.tar.gz -C /tmp/kc-install
        mv /tmp/kc-install/kubecolor "$HOME/.local/bin/kubecolor"
        rm -rf /tmp/kc-install
    fi

    # Node.js 22 via NodeSource
    if ! node --version 2>/dev/null | grep -q '^v22'; then
        echo "==> Installing Node.js 22..."
        curl -sSfL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # kubectl (official Kubernetes apt repo)
    if ! command -v kubectl &>/dev/null; then
        echo "==> Installing kubectl..."
        KUBECTL_MINOR=$(curl -sSL https://dl.k8s.io/release/stable.txt | grep -oE 'v[0-9]+\.[0-9]+')
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBECTL_MINOR}/deb/Release.key" \
            | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBECTL_MINOR}/deb/ /" \
            | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y kubectl
    fi

    # Docker (official apt repo)
    if ! command -v docker &>/dev/null; then
        echo "==> Installing Docker..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi

    echo "==> Writing ~/.zshrc..."
    {
        cat << 'HEADER'
# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=524288
SAVEHIST=524288
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY

# Plugins (Debian/Ubuntu system paths)
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
    source /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# Completions
autoload -Uz compinit && compinit

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^R'   history-incremental-search-backward
bindkey '^ '   autosuggest-accept
zstyle ':completion:*' menu yes select

# Tool hooks
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# User config
HEADER
        cat "$REPO_DIR/dotfiles/zsh/zshrc"
    } > "$HOME/.zshrc"

    # Meslo LG Nerd Font
    FONT_DIR="$HOME/.local/share/fonts/MesloNerdFont"
    if [ ! -d "$FONT_DIR" ]; then
        echo "==> Installing Meslo LG Nerd Font..."
        NERD_VER=$(curl -sSf https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        mkdir -p /tmp/meslo-install "$FONT_DIR"
        curl -sSfLo /tmp/meslo-install/Meslo.zip \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_VER}/Meslo.zip"
        unzip -q /tmp/meslo-install/Meslo.zip -d /tmp/meslo-install
        mv /tmp/meslo-install/*.ttf "$FONT_DIR/"
        rm -rf /tmp/meslo-install
        fc-cache -f "$FONT_DIR"
    fi

    echo ""
    echo "==> Linux: Docker daemon requires a system service."
    echo "    Enable now:          sudo systemctl enable --now docker"
    echo "    Add user to group:   sudo usermod -aG docker \$USER  (re-login required)"

fi

# ─────────────────────────────────────────────────────────────────────────────
# Dotfiles (same on both platforms)
# ─────────────────────────────────────────────────────────────────────────────
echo "==> Copying dotfiles..."

cp "$REPO_DIR/dotfiles/tmux/tmux.conf" "$HOME/.tmux.conf"

mkdir -p "$HOME/.config"
cp "$REPO_DIR/dotfiles/zsh/starship.toml" "$HOME/.config/starship.toml"

cp "$REPO_DIR/dotfiles/emacs/emacs" "$HOME/.emacs"

sed "s/__GIT_USER__/${GIT_USER_NAME}/g; s/__GIT_EMAIL__/${GIT_USER_EMAIL}/g" \
    "$REPO_DIR/dotfiles/git/gitconfig" > "$HOME/.gitconfig"

# ─────────────────────────────────────────────────────────────────────────────
# TPM
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "==> Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# ─────────────────────────────────────────────────────────────────────────────
# claude-code
# ─────────────────────────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
    echo "==> Installing claude-code via npm..."
    npm install -g @anthropic-ai/claude-code
else
    echo "==> claude-code already installed: $(claude --version 2>/dev/null || echo 'unknown')"
fi

echo ""
echo "==> Setup complete! Open a new terminal to activate your environment."
if [ "$OS" = "Darwin" ]; then
    echo ""
    echo "==> macOS: Docker daemon runs via colima."
    echo "    Start manually: colima start"
fi
echo ""
echo "==> To install tmux plugins, start tmux and press: Prefix + I"
