{
  description = "Nix tools for building Liqwid projects";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    extra-substituters = [ "https://cache.iog.io" "https://mlabs.cachix.org" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
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

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/templates.nix
        ./nix/all-modules.nix
        inputs.hercules-ci-effects.flakeModule
        inputs.pre-commit-hooks.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          utils = import ./nix/utils.nix { inherit pkgs lib; };
        in
        {
          pre-commit = {
            settings = {
              src = ./.;
              hooks = {
                nixpkgs-fmt.enable = true;
              };
            };
          };
          devShells.default = pkgs.mkShell {
            name = "liqwid-nix-dev-shell";
            buildInputs = [
              pkgs.nixpkgs-fmt
            ];
            shellHook = config.pre-commit.installationScript;
          };
          formatter = pkgs.nixpkgs-fmt;

          # This check is for `liqwid-nix` itself.
          checks.nixFormat =
            utils.shellCheck "nixFormat" ./. { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; } ''
              find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt
            '';
        };
      herculesCI = {
        ciSystems = [ "x86_64-linux" ];
        onPush.default.outputs = self.checks.x86_64-linux;
      };
    };
}
