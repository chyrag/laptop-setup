{
  description = "Python development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
      python = pkgs.python313;   # change to python312, python311 etc. as needed
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          python
          python.pkgs.pip
          python.pkgs.virtualenv
          pkgs.ruff         # linter + formatter
          pkgs.pyright      # type checker
        ];

        shellHook = ''
          echo "Python $(python3 --version)"
          # Create and activate a virtualenv if not already present
          if [ ! -d .venv ]; then
            python3 -m venv .venv
          fi
          source .venv/bin/activate
        '';
      };
    };
}
