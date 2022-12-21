{
  description = "Example Liqwid CTL project";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    extra-substituters = [ "https://cache.iog.io" "https://public-plutonomicon.cachix.org" "https://mlabs.cachix.org" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "public-plutonomicon.cachix.org-1:3AKJMhCLn32gri1drGuaZmFrmnue+KkKrhhubQk/CWc=" ];
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
          offchain.default = {
            src = ./.;

            runtime = {
              enableCtlServer = false;
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
            enableJsLintCheck = true;

            plutip = {
              buildInputs = [ ];
              testMain = "PlutipTest";
            };

            tests = {
              testMain = "Test.Main";
            };
          };
        };
    };
}
