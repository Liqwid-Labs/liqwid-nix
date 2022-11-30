{
  description = "Nix tools for building Liqwid projects";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    extra-substituters = [ "https://cache.iog.io" "https://public-plutonomicon.cachix.org" "https://mlabs.cachix.org" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "public-plutonomicon.cachix.org-1:3AKJMhCLn32gri1drGuaZmFrmnue+KkKrhhubQk/CWc=" ];
    allow-import-from-derivation = "true";
    bash-prompt = "\\[\\e[0m\\][\\[\\e[0;2m\\]liqwid-nix \\e[0;5m\\]2.0 \\[\\e[0;93m\\]\\w\\[\\e[0m\\]]\\[\\e[0m\\]$ \\[\\e[0m\\]";
    max-jobs = "auto";
    auto-optimise-store = "true";
  };

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";
    nixpkgs-2205.url = "github:NixOS/nixpkgs/nixos-22.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    # On-chain deps
    haskell-nix-extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage";
    haskell-nix-extra-hackage.inputs.haskell-nix.follows = "haskell-nix";
    haskell-nix-extra-hackage.inputs.nixpkgs.follows = "nixpkgs";
    haskell-nix.url = "github:input-output-hk/haskell.nix?rev=cbf1e918b6e278a81c385155605b8504e498efef";
    iohk-nix.url = "github:input-output-hk/iohk-nix/4848df60660e21fbb3fe157d996a8bac0a9cf2d6";
    iohk-nix.flake = false;

    ghc-next-packages.url = "github:input-output-hk/ghc-next-packages?ref=repo";
    ghc-next-packages.flake = false;

    haskell-language-server.url = "github:haskell/haskell-language-server";
    haskell-language-server.flake = false;
    plutarch.url = "github:Plutonomicon/plutarch-plutus?ref=emiflake/export-script-constructor";
  };

  outputs = { self, nixpkgs-2205, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [
        ./nix/templates.nix
        ./nix/all-modules.nix
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          pkgs2205 = import nixpkgs-2205 { inherit system; };
          utils = import ./nix/utils.nix { inherit pkgs lib; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "liqwid-nix-dev-shell";
            buildInputs = [
              pkgs2205.nixpkgs-fmt
            ];
          };
          formatter = pkgs2205.nixpkgs-fmt;

          # This check is for `liqwid-nix` itself.
          checks.nixFormat =
            utils.shellCheck "nixFormat" ./. { nativeBuildInputs = [ pkgs2205.nixpkgs-fmt ]; } ''
              find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt
            '';
        };
      flake = {
        config.hydraJobs = {
          packages = self.packages.x86_64-linux;
          checks = self.checks.x86_64-linux;
          devShells = self.devShells.x86_64-linux;
        };
      };
    };
}
