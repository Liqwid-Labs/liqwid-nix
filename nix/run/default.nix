# TODO: on-chain Plutarch project configuration module.
{ self, config, lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    mkPerSystemOption;
  inherit (lib)
    mkOption
    mkDefault
    types;
  inherit (types)
    functionTo
    raw;

in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, self', inputs', pkgs, system, ... }:
        let
          runScript = types.submodule {
            options = {
              dependencies = lib.mkOption {
                description = ''
                  The dependencies to include in the script's environment.
                '';
                type = types.listOf types.package;
              };
              script = lib.mkOption {
                description = ''
                  The script to run.
                '';
                type = types.str;
              };
              doCheck = lib.mkOption {
                description = ''
                  Whether this script should also be a check.
                '';
                type = types.bool;
              };
            };
          };
        in
        {
          options.run = lib.mkOption {
            description = ''
              Scripts that can be run using `nix run`.

              These are intended to replace makefiles.
            '';
            type = types.attrsOf runScript;
          };
        });
  };
}
