{
  description = "Go development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          go_1_23      # change to go_1_24 etc. as needed
          gopls
          delve        # debugger
          golangci-lint
        ];

        shellHook = ''
          echo "Go $(go version | awk '{print $3}')"
        '';
      };
    };
}
