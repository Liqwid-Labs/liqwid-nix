{ config, lib, flake-parts-lib, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkOption
    optionalAttrs
    types
    ;
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    mkPerSystemOption
    ;
in
{
  options = {
    flake = mkSubmoduleOptions {
      defaultDevShell = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = ''
          Which dev shell to use by default.
          <literal>nix develop</literal> will be equivalent to <literal>nix develop .##&lt;defaultDevShell></literal>
        '';
      };
    };

    perSystem = mkPerSystemOption
      ({ config, system, ... }: {
        options = {
          defaultDevShell = mkOption {
            type = types.nullOr types.string;
            default = null;
            description = ''
              Which dev shell to use by default.
              <literal>nix develop</literal> will be equivalent to <literal>nix develop .##&lt;defaultDevShell></literal>
            '';
          };
        };
      });
  };
  config = {
    flake.devShell = mapAttrs
      (k: v: v.devShells.${v.defaultDevShell})
      (filterAttrs (k: v: !(builtins.isNull v.defaultDevShell)) config.allSystems);

    perInput = system: flake:
      optionalAttrs (flake?devShell.${system}) {
        devShell = flake.devShell.${system};
      };
  };
}
