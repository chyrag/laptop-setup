{
  description = "Ruby development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = builtins.currentSystem;
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          ruby_3_4     # change to ruby_3_3, ruby_3_2 etc. as needed
          bundler
          rubocop
          solargraph   # LSP
        ];

        shellHook = ''
          echo "Ruby $(ruby --version)"
          export GEM_HOME="$PWD/.gems"
          export PATH="$GEM_HOME/bin:$PATH"
        '';
      };
    };
}
