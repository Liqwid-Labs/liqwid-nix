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
          builtins.attrValues exposedModules ++ [
            # flake modules from other flake libraries
            self.inputs.hercules-ci-effects.flakeModule
            self.inputs.pre-commit-hooks.flakeModule
          ];
      };
    } // exposedModules;
  };
}
