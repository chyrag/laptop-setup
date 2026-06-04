{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tmux
    eza
    bat
    fd
    fzf
    ripgrep
    jq
    yq-go
    zoxide
    nodejs_22    # npm + claude-code dependency
    emacs
    kubecolor
    notmuch
    isync    # provides mbsync
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
