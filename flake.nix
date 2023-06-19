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
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    iohk-nix.url = "github:input-output-hk/iohk-nix";
    iohk-nix.inputs.nixpkgs.follows = "nixpkgs";

    CHaP.url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
    CHaP.flake = false;

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
      perSystem = { options, config, self', inputs', pkgs, lib, system, ... }:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          utils = import ./nix/utils.nix { inherit pkgs lib; };
          doc-modules = (inputs.flake-parts.lib.evalFlakeModule
            {
              inherit inputs;
            }
            {
              imports = [
                ./nix/onchain.nix
                ./nix/run.nix
                ./nix/offchain.nix
                # FIXME: This module doesn't seem to work yet.
                # ./nix/ci-config.nix
              ];
            });
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
          packages.options-doc = (pkgs.nixosOptionsDoc { inherit (doc-modules) options; }).optionsCommonMark;
          packages.publish-docs = pkgs.writeScript "publish-docs.sh" ''
            rev=$(git rev-parse --short HEAD)
            cat ${self.packages.${system}.options-doc} > ./docs/reference/modules.md
            rm -rf book
            ${pkgs.mdbook}/bin/mdbook build
            touch book/.nojekyll
            git fetch origin
            git checkout gh-pages
            GIT_WORK_TREE=$(pwd)/book git add -A
          '';

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
