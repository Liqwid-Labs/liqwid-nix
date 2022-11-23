{ config, lib, flake-parts-lib, ... }:
let
  modules = {
    onchain = ./onchain.nix;
    run = ./run/default.nix;
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

