{
  description = "Example Liqwid Plutarch project";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    nixpkgs-latest.url = "github:NixOS/nixpkgs";
    # temporary fix for nix versions that have the transitive follows bug
    # see https://github.com/NixOS/nix/issues/6013
    nixpkgs-2111 = { url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin"; };
    nixpkgs-2205 = { url = "github:NixOS/nixpkgs/nixos-22.05"; };

    haskell-nix-extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage";
    haskell-nix-extra-hackage.inputs.haskell-nix.follows = "haskell-nix";
    haskell-nix-extra-hackage.inputs.nixpkgs.follows = "nixpkgs";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    iohk-nix.url = "github:input-output-hk/iohk-nix";
    iohk-nix.flake = false;

    # Plutarch and its friends
    plutarch.url = "github:Plutonomicon/plutarch-plutus?ref=master";

    haskell-language-server.url = "github:haskell/haskell-language-server";
    haskell-language-server.flake = false;

    ply = {
      url = "github:mlabs-haskell/ply?ref=master";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.plutarch.follows = "plutarch";
    };
    plutarch-numeric = {
      url = "github:Liqwid-Labs/plutarch-numeric?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-latest.follows = "nixpkgs-latest";
      inputs.nixpkgs-2111.follows = "nixpkgs-2111";
      inputs.haskell-nix-extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.haskell-language-server.follows = "haskell-language-server";
      inputs.plutarch.follows = "plutarch";
    };
    liqwid-plutarch-extra = {
      url = "github:Liqwid-Labs/liqwid-plutarch-extra?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-latest.follows = "nixpkgs-latest";
      inputs.nixpkgs-2111.follows = "nixpkgs-2111";
      inputs.nixpkgs-2205.follows = "nixpkgs-2205";
      inputs.haskell-nix-extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.haskell-language-server.follows = "haskell-language-server";
      inputs.plutarch.follows = "plutarch";
      inputs.plutarch-quickcheck.follows = "plutarch-quickcheck";
      inputs.plutarch-numeric.follows = "plutarch-numeric";
      inputs.plutarch-context-builder.follows = "plutarch-context-builder";
      inputs.ply.follows = "ply";
    };
    plutarch-quickcheck = {
      url = "github:liqwid-labs/plutarch-quickcheck?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-latest.follows = "nixpkgs-latest";
      inputs.nixpkgs-2111.follows = "nixpkgs-2111";
      inputs.haskell-nix-extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.haskell-language-server.follows = "haskell-language-server";
      inputs.plutarch.follows = "plutarch";
    };
    plutarch-context-builder = {
      url = "github:Liqwid-Labs/plutarch-context-builder?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-latest.follows = "nixpkgs-latest";
      inputs.nixpkgs-2111.follows = "nixpkgs-2111";
      inputs.haskell-nix-extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.haskell-language-server.follows = "haskell-language-server";
      inputs.plutarch.follows = "plutarch";
    };
    liqwid-script-export = {
      url = "github:Liqwid-Labs/liqwid-script-export?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-latest.follows = "nixpkgs-latest";
      inputs.nixpkgs-2111.follows = "nixpkgs-2111";
      inputs.haskell-nix-extra-hackage.follows = "haskell-nix-extra-hackage";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.iohk-nix.follows = "iohk-nix";
      inputs.haskell-language-server.follows = "haskell-language-server";
      inputs.plutarch.follows = "plutarch";
      inputs.ply.follows = "ply";
      inputs.plutarch-numeric.follows = "plutarch-numeric";
      inputs.liqwid-plutarch-extra.follows = "liqwid-plutarch-extra";
    };
    liqwid-nix = {
      url = "github:Liqwid-Labs/liqwid-nix/emiflake/formatters";
      inputs.nixpkgs-2205.follows = "nixpkgs-2205";
    };
  };

  outputs = { self, liqwid-nix, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [
        liqwid-nix.onchain
        liqwid-nix.run
        ./.
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: { };
    };
}
