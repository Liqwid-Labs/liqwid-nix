{
  description = "Example Liqwid Plutarch project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    liqwid-nix.url = "github:Liqwid-Labs/liqwid-nix/liqwid-nix-2.0";

    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";
    nixpkgs-2111.url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin";
    nixpkgs-2205.follows = "liqwid-nix/nixpkgs-2205";

    iohk-nix.follows = "plutarch/iohk-nix";
    haskell-nix-extra-hackage.follows = "plutarch/haskell-nix-extra-hackage";
    haskell-nix.follows = "plutarch/haskell-nix";
    haskell-language-server.follows = "plutarch/haskell-language-server";

    plutarch = {
      url = "github:Plutonomicon/plutarch-plutus?ref=master";
      inputs.emanote.follows =
        "plutarch/haskell-nix/nixpkgs-unstable";
      inputs.nixpkgs.follows =
        "plutarch/haskell-nix/nixpkgs-unstable";
    };

    plutarch-numeric.url =
      "github:Liqwid-Labs/plutarch-numeric?ref=main";
    plutarch-safe-money.url =
      "github:Liqwid-Labs/plutarch-safe-money?ref=main";
    liqwid-plutarch-extra.url =
      "github:Liqwid-Labs/liqwid-plutarch-extra?ref=main";
    plutarch-quickcheck.url =
      "github:liqwid-labs/plutarch-quickcheck?ref=staging";
    plutarch-context-builder.url =
      "github:Liqwid-Labs/plutarch-context-builder?ref=main";
    liqwid-script-export.url =
      "github:Liqwid-Labs/liqwid-script-export?ref=main";
  };

  outputs = { self, liqwid-nix, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [
        liqwid-nix.onchain
        ./onchain
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: { };
    };
}
