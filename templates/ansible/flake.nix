{
  description = "Ansible development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          ansible
          ansible-lint
          python313          # for ad-hoc modules / scripts
          python313.pkgs.pip
        ];

        shellHook = ''
          echo "Ansible $(ansible --version | head -1)"
        '';
      };
    };
}
