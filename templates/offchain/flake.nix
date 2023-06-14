{
  description = "Example Liqwid CTL project";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://cache.iog.io" "https://mlabs.cachix.org" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
    allow-import-from-derivation = "true";
    max-jobs = "auto";
    auto-optimise-store = "true";
  };

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    liqwid-nix.url = "github:Liqwid-Labs/liqwid-nix";
    nixpkgs.url = "github:NixOS/nixpkgs";

    cardano-transaction-lib.url = "github:Plutonomicon/cardano-transaction-lib/develop";
    nixpkgs-ctl.follows = "cardano-transaction-lib/nixpkgs";
  };

  outputs = inputs@{ liqwid-nix, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.liqwid-nix.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, pkgs', self', inputs', system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
          };
        in
        {
          pre-commit = {
            settings = {
              src = ./.;
              excludes = [ "spago-packages.nix" ];
              hooks = {
                nixpkgs-fmt.enable = true;
                purs-tidy.enable = true;
                dhall-format.enable = true;
              };
            };
          };
          offchain.default = {
            src = ./.;
            packageJson = ./package.json;
            packageLock = ./package-lock.json;

            submodules = [ ];

            runtime = {
              enableCtlServer = false;
              exposeConfig = false;
            };

            bundles = {
              web-bundle = {
                mainModule = "Main";
                browserRuntime = true;
                entrypointJs = "index.js";
                webpackConfig = "webpack.config.js";
                bundledModuleName = "output.js";
                enableCheck = true;
              };
            };

            shell = { };
            enableFormatCheck = true;
            enableJsLintCheck = false;

            plutip = {
              buildInputs = [ ];
              testMain = "PlutipTest";
            };

            tests = {
              testMain = "Test.Main";
            };
          };

          ci.required = [ "all_offchain" ];

          apps = inputs.cardano-transaction-lib.inputs.cardano-node.apps;
        };
    };
}
