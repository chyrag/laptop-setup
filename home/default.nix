{ config, pkgs, ... }:
{
  # Requires --impure to read USER from environment.
  home.username = builtins.getEnv "USER";
  home.homeDirectory =
    if pkgs.stdenv.isDarwin
    then "/Users/${config.home.username}"
    else "/home/${config.home.username}";

  home.stateVersion = "24.11";

  # home-manager manages itself
  programs.home-manager.enable = true;

  imports = [
    ./modules/packages.nix
    ./modules/packages-ops.nix
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/emacs.nix
    ./modules/fonts.nix
  ];
}
