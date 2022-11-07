{ config, lib, flake-parts-lib, ... }:
let
  modules = {
    onchain = ./onchain.nix;
  };
in
{
  config = {
    flake = {
      all-modules = {
        import = builtins.attrValues modules;
      };
    } // modules;
  };
}

