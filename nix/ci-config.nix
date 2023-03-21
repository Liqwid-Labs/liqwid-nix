{ self, lib, flake-parts-lib, ... }:
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
          ci = types.submodule
            {
              options = {
                required = lib.mkOption {
                  description = ''
                    The checks that CI must run, expressed as keys of the `checks.<system>` attribute list.

                    Added in: 2.0.0.
                  '';
                  default = [ ];
                  type = types.listOf types.str;
                };
                addRunScript = lib.mkOption {
                  description = ''
                    Whether or not to add a helpful run script that just builds `checks.<system>.required`.

                    Added in: 2.0.0.
                  '';
                  default = true;
                  type = types.bool;
                };
                systems = lib.mkOption {
                  description = ''
                    The systems to build on.

                    Added in: 2.1.0.
                  '';
                  default = [ "x86_64-linux" ];
                  type = types.listOf types.str;
                };
              };
            };
        in
        {
          options.ci = lib.mkOption {
            description = ''
              Options for CI under liqwid-nix modules.

              This module will expose the `required` check, if checks are provided. This
              can be used in the VCS as a pre-merge requirement for PRs.

              Added in: 2.0.0.
            '';
            default = { };
            type = ci;
          };
        }
      );
  };
  config = {
    flake = { ... }: {
      config.herculesCI = {
        ciSystems = [ "x86_64-linux" ];
        onPush.default.outputs = self.checks.x86_64-linux;
      };
    };
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        pkgs = import self.inputs.nixpkgs {
          inherit system;
        };
        utils = import ./utils.nix { inherit pkgs lib; };

        desiredChecks =
          pkgs.lib.genAttrs config.ci.required (name: config.checks.${name});

        combinedChecks = utils.combineChecks "combined-checks" desiredChecks;
      in
      {
        checks.required = combinedChecks;
        run =
          if config.ci.addRunScript then
            {
              ci = {
                script = ''
                  nix build .#checks.${system}.required
                '';
                help = ''
                  echo "  Simply runs the \`required\` check for the given system.'"
                '';
              };
            }
          else
            { };
      };
  };
}


