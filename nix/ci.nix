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
          hercules = types.submodule
            {
              options = {
                enable = lib.mkOption {
                  decription = ''
                    Whether to configure hercules.
                     
                    Added in: 2.1.0.
                  '';
                  type = types.bool;
                  default = true;
                };
              };
            };
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
                hercules = lib.mkOption {
                  description = ''
                    Options for Hercules specific configuration.

                    Added in 2.1.0.
                  '';
                  default = { };
                  type = hercules;
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
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        pkgs = import self.inputs.nixpkgs {
          inherit system;
        };
        utils = import ./utils.nix { inherit pkgs lib; };

        desiredChecks =
          pkgs.lib.genAttrs config.ci.required (name: config.checks.${name});

        combinedChecks = utils.combineChecks "combined-checks" desiredChecks;

        hercules =
          lib.ifEnable config.ci.hercules.enable
            {
              herculesCI = { ... }: {
                onPush.default = {
                  outputs = { ... }: desiredChecks;
                };
              };
            };
      in
      {
        checks.required = combinedChecks;
        run = lib.ifEnable config.ci.addRunScript
          {
            ci = {
              script = ''
                nix build .#checks.${system}.required
              '';
              help = ''
                echo "  Simply runs the \`required\` check for the given system.'"
              '';
            };
          };
      };
  };
}


