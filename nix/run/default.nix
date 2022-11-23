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
          runScript = types.submodule
            {
              options = {
                dependencies = lib.mkOption {
                  description = ''
                    The dependencies to include in the script's environment.
                  '';
                  type = types.listOf types.package;
                  default = [ ];
                };
                script = lib.mkOption {
                  description = ''
                    The script to run.
                  '';
                  type = types.str;
                  default = "echo UNIMPLEMENTED RUN SCRIPT";
                };
                doCheck = lib.mkOption {
                  description = ''
                    Whether this script should also be a check.
                  '';
                  type = types.bool;
                  default = false;
                };
                groups = lib.mkOption {
                  description = ''
                    Setting group allows running multiple run scripts all at once.

                    These groups will be aliases to all of the scripts that tagged them.
                  '';
                  type = types.listOf types.str;
                  default = [ ];
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
            default = { };
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        pkgs = import self.inputs.nixpkgs {
          inherit system;
        };

        buildGroup = groupName: configs:
          {
            type = "app";
            program = pkgs.writeShellApplication {

              name = "group";
              runtimeInputs = lib.concatLists (builtins.map (c: c.dependencies) configs);
              text = ''
                export LC_CTYPE=C.UTF-8
                export LC_ALL=C.UTF-8
                export LANG=C.UTF-8
                set -x

                # Scripts follow
                ${lib.concatStringsSep "\n\n" (builtins.map (c: c.script) configs)}
              '';
            };
          };

        makeGroups = name: config: pkgs.lib.genAttrs config.groups (f: [ config ]);

        makeApp = name: config:
          {
            type = "app";
            program =
              pkgs.writeShellApplication
                {
                  inherit name;
                  runtimeInputs = config.dependencies;
                  text = ''
                    export LC_CTYPE=C.UTF-8
                    export LC_ALL=C.UTF-8
                    export LANG=C.UTF-8
                    echo "hi"
                    ${config.script}
                  '';
                };
          };
        groups =
          lib.mapAttrs buildGroup
            (lib.foldr
              (lib.mergeAttrsWithFunc (a: b: a ++ b))
              { }
              (builtins.attrValues
                (lib.mapAttrs makeGroups config.run)));
        apps = (lib.mapAttrs makeApp config.run // groups);
      in
      {
        inherit apps;
      };
  };
}
