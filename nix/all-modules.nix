{ config, self, lib, flake-parts-lib, ... }:
let
  # Which modules do we want to expose to consumers of liqwid-nix.
  exposedModules = {
    onchain = ./onchain.nix;
    offchain = ./offchain.nix;
    run = ./run.nix;
    ci = ./ci-config.nix;
  };
in
{
  config = {
    flake = {
      allModules = builtins.attrValues exposedModules;
      flakeModule = {
        imports =
          builtins.attrValues exposedModules ++ (with self.inputs; [
            # flake modules from other flake libraries
            pre-commit-hooks.flakeModule
          ]);
      };
    } // exposedModules;
  };
}
