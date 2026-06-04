{
  description = "Terraform infrastructure environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          terraform
          terraform-ls    # LSP
          tflint
        ];

        shellHook = ''
          echo "Terraform $(terraform version | head -1)"
        '';
      };
    };
}
