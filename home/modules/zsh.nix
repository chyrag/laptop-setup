{ pkgs, lib, shellTheme ? "starship", ... }:

let
  useOhMyZsh = shellTheme == "ohmyzsh";
in

lib.mkMerge [

  # ── Common to both themes ─────────────────────────────────────────────────
  {
    programs.zsh = {
      enable = true;
      history = {
        path          = "$HOME/.zsh_history";
        size          = 524288;
        save          = 524288;
        ignoreAllDups = true;
        share         = true;
      };
    };

    # direnv hook is added automatically because programs.direnv is enabled
    # in packages.nix alongside programs.zsh.enable.

    programs.zoxide = {
      enable              = true;
      enableZshIntegration = true;
    };

    # p10k config — used by oh-my-zsh theme; harmless when using starship.
    home.file.".p10k.zsh".source = ../../dotfiles/zsh/p10k.zsh;
  }

  # ── Starship (default) ────────────────────────────────────────────────────
  (lib.mkIf (!useOhMyZsh) {
    home.packages = [ pkgs.starship ];

    programs.starship = {
      enable              = true;
      enableZshIntegration = true;
    };

    programs.zsh = {
      # Plugins sourced directly from Nix store — no network on shell startup.
      plugins = [
        {
          name = "fast-syntax-highlighting";
          src  = pkgs.zsh-fast-syntax-highlighting;
          file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
        }
        {
          name = "zsh-autosuggestions";
          src  = pkgs.zsh-autosuggestions;
          file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "zsh-history-substring-search";
          src  = pkgs.zsh-history-substring-search;
          file = "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
        }
        {
          name = "fzf-tab";
          src  = pkgs.zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }
      ];

      initContent = ''
        # OMZ snippets sourced directly — no full oh-my-zsh installation needed
        source ${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/sudo/sudo.plugin.zsh
        source ${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/git/git.plugin.zsh
        source ${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/command-not-found/command-not-found.plugin.zsh

        # Completions
        autoload -Uz compinit && compinit

        # eza completions
        source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/key-bindings.zsh 2>/dev/null || true

        # History substring search key bindings
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        autoload -U up-line-or-beginning-search down-line-or-beginning-search
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
        bindkey '^R'   history-incremental-search-backward
        bindkey '^ '   autosuggest-accept

        zstyle ':completion:*' menu yes select

        # User config (environment, aliases, PATH additions)
        ${builtins.readFile ../../dotfiles/zsh/zshrc}
      '';
    };
  })

  # ── Oh-my-zsh + Powerlevel10k ─────────────────────────────────────────────
  (lib.mkIf useOhMyZsh {
    home.packages = [ pkgs.zsh-powerlevel10k ];

    programs.zsh = {
      oh-my-zsh = {
        enable  = true;
        # "z" omitted — zoxide (enabled above) provides the z command
        plugins = [ "git" "docker" "kubectl" "gcloud" "aws" "fzf" ];
      };

      # p10k instant prompt must run before everything else
      initExtraFirst = ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '';

      initContent = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

        # User config (environment, aliases, PATH additions)
        ${builtins.readFile ../../dotfiles/zsh/zshrc}
      '';
    };
  })
]
