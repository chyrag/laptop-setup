{
  description = "OpenTofu infrastructure environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          opentofu
          tflint       # works with opentofu too
        ];

        shellHook = ''
          echo "OpenTofu $(tofu version | head -1)"
        '';
      };
    };
}
