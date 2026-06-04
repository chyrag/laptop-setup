{
  description = "Laptop setup — Nix + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      # Requires --impure so builtins.currentSystem and builtins.getEnv work.
      system = builtins.currentSystem;
      pkgs = nixpkgs.legacyPackages.${system};
      osModule =
        if pkgs.stdenv.isDarwin
        then ./home/darwin.nix
        else ./home/linux.nix;
    in
    {
      homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/default.nix osModule ];
        # shellTheme: "starship" (default) or "ohmyzsh"
        # Set via SHELL_THEME env var: make switch SHELL_THEME=ohmyzsh
        extraSpecialArgs = {
          shellTheme =
            let t = builtins.getEnv "SHELL_THEME";
            in if t == "" then "starship" else t;
        };
      };

      # Per-project devShell templates — added in Phase 4.
      # Usage: nix flake init -t /path/to/laptop-setup#go
      #        (or via scripts/mkdev.sh)
      templates = { };
    };
}
