{ config, lib, flake-parts-lib, ... }:
let
  # Which modules do we want to expose to consumers of liqwid-nix.
  exposedModules = {
    onchain = ./onchain.nix;
    offchain = ./offchain.nix;
    run = ./run.nix;
    ci = ./ci.nix;
  };
in
{
  config = {
    flake = {
      allModules = builtins.attrValues exposedModules;
      flakeModule = {
        imports = builtins.attrValues exposedModules;
      };
    } // exposedModules;
  };
}

