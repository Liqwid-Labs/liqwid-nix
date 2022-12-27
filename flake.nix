{
  description = "Nix tools for building Liqwid projects";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    extra-substituters = [ "https://cache.iog.io" "https://public-plutonomicon.cachix.org" "https://mlabs.cachix.org" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "public-plutonomicon.cachix.org-1:3AKJMhCLn32gri1drGuaZmFrmnue+KkKrhhubQk/CWc=" ];
    allow-import-from-derivation = "true";
    max-jobs = "auto";
    auto-optimise-store = "true";
  };

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    # On-chain deps
    haskell-nix.url = "github:input-output-hk/haskell.nix?rev=cbf1e918b6e278a81c385155605b8504e498efef";
    iohk-nix.url = "github:input-output-hk/iohk-nix?rev=4848df60660e21fbb3fe157d996a8bac0a9cf2d6";
    iohk-nix.flake = false;

    ghc-next-packages.url = "github:input-output-hk/ghc-next-packages?ref=repo";
    ghc-next-packages.flake = false;

    plutarch.url = "github:Plutonomicon/plutarch-plutus?ref=master";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/templates.nix
        ./nix/all-modules.nix
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          utils = import ./nix/utils.nix { inherit pkgs lib; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "liqwid-nix-dev-shell";
            buildInputs = [
              pkgs.nixpkgs-fmt
            ];
          };
          formatter = pkgs.nixpkgs-fmt;

          # This check is for `liqwid-nix` itself.
          checks.nixFormat =
            utils.shellCheck "nixFormat" ./. { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; } ''
              find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt
            '';
        };
      flake = { self, ... }: {
        config.hydraJobs = {
          packages = self.packages.x86_64-linux;
          checks = self.checks.x86_64-linux;
          devShells = self.devShells.x86_64-linux;
        };
        config.herculesCI = { ... }: {
          onPush.default = {
            outputs = { ... }:
              self.checks.x86_64-linux;
          };
          ciSystems = [ "x86_64-linux" ];
        };
      };
    };
}
