{
  description = "Rust development environment";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      system = builtins.currentSystem;
      pkgs   = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      # Pin to a specific toolchain via rust-toolchain.toml, or use a channel:
      rust = pkgs.rust-bin.stable.latest.default.override {
        extensions = [ "rust-src" "rust-analyzer" ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ rust pkgs.cargo-edit pkgs.cargo-watch ];

        shellHook = ''
          echo "Rust $(rustc --version)"
        '';
      };
    };
}
