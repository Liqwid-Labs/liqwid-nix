{ self, config, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    mkPerSystemOption;

  inherit (lib) types;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, self', inputs', pkgs, system, ... }:
        let

          shell = types.submodule {
            options = {
              extraCommandLineTools = lib.mkOption {
                type = types.listOf types.package;
                description = ''
                  List of extra packages to make available to the shell.

                  Added in: 2.0.
                '';
                default = [ ];
              };
            };
          };

          bundle = types.submodule {
            options = {
              sources = lib.mkOption {
                description = '' FIXME '';
                default = [ ];
              };

              main = lib.mkOption {
                description = '' FIXME '';
                type = types.path;
              };

              entrypoint = lib.mkOption {
                description = '' FIXME '';
                type = types.path;
              };

              browserRuntime = lib.mkOption {
                description = '' FIXME '';
                type = types.bool;
                default = true;
              };

              webpackConfig = lib.mkOption {
                description = '' FIXME '';
                type = types.string;
                default = "webpack.config.js";
              };

              bundledModuleName = lib.mkOption {
                description = '' FIXME '';
                type = types.string;
                default = "output.js";
              };

              enableCheck = lib.mkOption {
                description = '' FIXME '';
                type = types.bool;
                default = false;
              };
            };
          };

          testConfigs = types.submodule {
            options = {
              sources = lib.mkOption {
                type = types.listOf types.string;
                description = '' FIXME '';
                default = [ ];
              };

              buildInputs = lib.mkOption {
                type = types.listOf types.package;
                description = '' FIXME '';
                default = [ ];
              };

              testMain = lib.mkOption {
                description = '' FIXME '';
                type = types.string;
              };
            };
          };

          runtime = types.submodule {
            options = {
              enableCtlServer = lib.mkOption {
                description = '' FIXME '';
                type = types.bool;
                default = false;
              };

              extraConfig = lib.mkOption {
                description = '' FIXME '';
                type = types.attrs;
                default = { };
              };
            };
          };

          project = types.submodule {
            options = {
              src = lib.mkOption {
                description = ''
                  Path to the project's source code.

                  Added in: 2.0.
                '';
                type = types.path;
              };

              censoredSpagoCodes = lib.mkOption {
                description = '' FIXME '';
                default = [ ];
                type = types.listOf types.string;
              };

              shell = lib.mkOption {
                description = '' FIXME '';
                type = shell;
                default = { };
              };

              bundles = lib.mkOption {
                description = '' FIXME '';
                type = types.attrsOf bundle;
                default = { };
              };

              plutip = lib.mkOption {
                description = '' FIXME '';
                type = types.nullOr testConfigs;
                default = null;
              };

              tests = lib.mkOption {
                description = '' FIXME '';
                type = types.nullOr testConfigs;
                default = null;
              };

              runtime = lib.mkOption {
                description = '' FIXME '';
                type = runtime;
                default = { };
              };

              enableFormatCheck = lib.mkOption {
                description = '' FIXME '';
                type = types.bool;
                default = false;
              };

              enableJsLintCheck = lib.mkOption {
                description = '' FIXME '';
                type = types.bool;
                default = false;
              };
            };
          };
        in
        {
          options.offchain = lib.mkOption {
            description = "Off-chain project declaration";
            type = types.attrsOf project;
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', lib, system, ... }:
      let
        defaultCtlOverlays = [
          self.inputs.cardano-transaction-lib.overlays.purescript
          self.inputs.cardano-transaction-lib.overlays.runtime
        ];

        liqwid-nix = self.inputs.liqwid-nix.inputs;
        pkgs = import liqwid-nix.nixpkgs-ctl {
          inherit system;
          overlays =
            [
              self.inputs.cardano-transaction-lib.overlays.purescript
              self.inputs.cardano-transaction-lib.overlays.runtime
              self.inputs.cardano-transaction-lib.overlays.ctl-server
            ];
        };

        utils = import ./utils.nix { inherit pkgs lib; };

        makeProject = projectName: projectConfig:
          let
            defaultCommandLineTools = with pkgs; [
              dhall
              easy-ps.purs-tidy
              fd
              nixpkgs-fmt
              nodePackages.eslint
              nodePackages.npm
              nodePackages.prettier
              nodejs
            ];

            commandLineTools =
              defaultCommandLineTools
              ++ projectConfig.shell.extraCommandLineTools;

            project =
              let
                pkgSet = pkgs.purescriptProject {
                  inherit (projectConfig) src;

                  inherit projectName;

                  censorCodes = projectConfig.censoredSpagoCodes;

                  shell = {
                    withRuntime = true;
                    packageLockOnly = true;
                    packages = commandLineTools;
                  };
                };
              in
              pkgSet;

            bundles = (lib.mapAttrs
              (_: bundle: project.bundlePursProject {
                inherit (bundle) main entrypoint;
              })
              projectConfig.bundles);

            checks = {
              bundle-checks =
                utils.flat2With (bundleName: _: bundleName)
                  (lib.mapAttrs (bundleName: _: bundles.${bundleName})
                    (lib.filterAttrs (_: bundle: bundle.enableCheck)
                      projectConfig.bundles));

              tests =
                lib.ifEnable
                  (projectConfig ? tests)
                  (project.runPursTest {
                    inherit (projectConfig.tests)
                      sources
                      buildInputs
                      testMain;
                  });

              plutip-tests =
                lib.ifEnable
                  (projectConfig ? plutip)
                  (project.runPlutipTest {
                    inherit (projectConfig.plutip)
                      sources
                      buildInputs
                      testMain;
                  });

              formatting-check =
                lib.ifEnable
                  projectConfig.enableFormatCheck
                  (pkgs.runCommand "formatting-check"
                    {
                      nativeBuildInputs = commandLineTools;
                    }
                    ''
                      cd ${self}
                      purs-tidy check $(fd -epurs)
                      nixpkgs-fmt --check $(fd -enix --exclude='spago*')
                      prettier -c $(fd -ejs)
                      touch $out
                    '');

              js-lint-check =
                lib.ifEnable
                  projectConfig.enableJsLintCheck
                  (pkgs.runCommand "js-lint-check"
                    {
                      nativeBuildInputs = commandLineTools;
                    }
                    ''
                      cd ${self}
                      eslint $(fd -ejs)
                      touch $out
                    '');
            };

            ctlRuntimeConfig = projectConfig.runtime.extraConfig // {
              ctlServer.enable = projectConfig.runtime.enableCtlServer;
            };
          in
          {
            packages = {
              ctl-runtime = pkgs.buildCtlRuntime ctlRuntimeConfig { };
            } // bundles;

            inherit checks;
            check = utils.combineChecks "combined-checks" checks;

            apps = {
              ctl-runtime = pkgs.launchCtlRuntime ctlRuntimeConfig;
              docs = project.launchSearchablePursDocs { };
            };

            devShell = project.devShell;
          };

        projects = lib.mapAttrs makeProject config.offchain;

        projectChecks =
          lib.filterAttrs (_: check: check != { })
            (utils.flat2With (project: check: project + "_" + check)
              (lib.mapAttrs
                (_: project: project.checks // { all = project.check; })
                projects));
      in
      {
        packages =
          utils.flat2With (projectName: packageName: projectName + "_" + packageName)
            (lib.mapAttrs
              (_: project: project.packages)
              projects);

        apps =
          utils.flat2With (projectName: appName: projectName + "_" + appName)
            (lib.mapAttrs
              (_: project: project.apps)
              projects);

        checks = projectChecks // {
          all_offchain = utils.combineChecks "all_onchain" projectChecks;
        };

        devShells = lib.mapAttrs (_: project: project.devShell) projects;
      };
  };
}
