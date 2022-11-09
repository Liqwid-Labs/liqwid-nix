{
  description = "Example Liqwid CTL project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    liqwid-nix.url = "github:Liqwid-Labs/liqwid-nix/liqwid-nix-2.0";

    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";
    nixpkgs-2111.url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin";
    nixpkgs-2205.follows = "liqwid-nix/nixpkgs-2205";

    cardano-transaction-lib.url = "github:Plutonomicon/cardano-transaction-lib/develop";
    nixpkgs-ctl.follows = "cardano-transaction-lib/nixpkgs";
  };

  outputs = { self, liqwid-nix, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [
        liqwid-nix.onchain
        ./offchain
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: { };
    };
}
