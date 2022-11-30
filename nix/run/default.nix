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

                    Added in: 2.0.
                  '';
                  type = types.listOf types.package;
                  default = [ ];
                };
                script = lib.mkOption {
                  description = ''
                    The script to run.

                    Added in: 2.0.
                  '';
                  type = types.str;
                  default = "echo UNIMPLEMENTED RUN SCRIPT";
                };
                doCheck = lib.mkOption {
                  description = ''
                    Whether this script should also be a check.

                    Added in: 2.0.
                  '';
                  type = types.bool;
                  default = false;
                };
                groups = lib.mkOption {
                  description = ''
                    Setting group allows running multiple run scripts all at once.

                    These groups will be aliases to all of the scripts that tagged them.

                    Added in: 2.0.
                  '';
                  type = types.listOf types.str;
                  default = [ ];
                };
                help = lib.mkOption {
                  description = ''
                    Help message to provide when using `nix run .#help -- <name>`.

                    Added in: 2.0.
                  '';
                  type = types.str;
                  default = "No help provided.";
                };
              };
            };
        in
        {
          options.run = lib.mkOption {
            description = ''
              Scripts that can be run using `nix run`.

              These are intended to replace makefiles.

              Added in: 2.0.
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
                    set -x

                    # ${name}
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
        apps = (lib.mapAttrs makeApp config.run // groups
          // {
          help = {
            type = "app";
            program =
              let
                renderGroups = gs:
                  if builtins.length gs == 0 then
                    ""
                  else
                    "(groups: ${builtins.concatStringsSep ", " gs})";
                renderCase = name: script:
                  ''${name})
                  echo "usage: nix run .#${name}"
                  echo
                  ${script.help}
                ;;'';
              in
              pkgs.writeShellApplication
                {
                  name = "help";
                  text = ''
                    if [ $# -eq 1 ]; then
                      case $1 in
                        ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs renderCase config.run))}
                        *) echo "error: run script $1 not found"; exit 1 ;;
                      esac
                    else
                      echo "usage: nix run .#<name>"
                      echo
                      echo "  Groups run multiple scripts at once. These are commonly used"
                      echo "  for formatting and linting. To get a description of a particular"
                      echo "  script, use \`nix run .#help -- <name>\`."
                      echo
                      echo "Available scripts:"
                      echo "${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (n: c: "  ${n} ${renderGroups c.groups}") config.run))}"
                      echo
                      echo "Available groups:"
                      echo "${builtins.concatStringsSep "\n" (builtins.map (p: "  " + p) (builtins.attrNames groups))}"
                    fi
                  '';
                };
          };
        });
      in
      {
        inherit apps;
      };
  };
}

