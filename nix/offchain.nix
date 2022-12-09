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

                  Added in: 2.1.
                '';
                default = [ ];
              };
            };
          };

          # NOTE: probably a simple types.str would be enough here, but we want
          # to differentiate this kind of string from stringified paths, which
          # is what most of CTL's flake takes as input.
          purescriptModule =
            types.strMatching
              ''[[:upper:]][[:alnum:]]*(\.[[:upper:]][[:alnum:]]*)*'';

          bundle = types.submodule {
            options = {
              mainModule = lib.mkOption {
                description = ''
                  The main Purescript module for the bundle (for instance, 'Main').

                  Added in: 2.1
                '';
                type = purescriptModule;
              };

              entrypointJs = lib.mkOption {
                description = ''
                  Stringified path to the webpack `entrypoint` file.

                  Added in: 2.1
                '';

                # NOTE: ideally, this would be a types.path, but it's easier to
                # conform to CTL's types.
                type = types.str;
                default = "index.js";
              };

              browserRuntime = lib.mkOption {
                description = ''
                  Whether this bundle is being produced for a browser environment or
                  not.

                  Added in: 2.1
                '';
                type = types.bool;
                default = true;
              };

              webpackConfig = lib.mkOption {
                description = ''
                  Stringified path to the Webpack config file to use.

                  Added in: 2.1
                '';
                type = types.str;
                default = "webpack.config.js";
              };

              bundledModuleName = lib.mkOption {
                description = ''
                  The name of the file containing the bundled JS module that
                  `spago bundle-module` will produce.

                  Added in: 2.1
                '';
                type = types.str;
                default = "output.js";
              };

              enableCheck = lib.mkOption {
                description = ''
                  Whether to add a flake check testing that the bundle builds
                  correctly.

                  Added in: 2.1
                '';
                type = types.bool;
                default = false;
              };
            };
          };

          testConfigs = types.submodule {
            options = {
              buildInputs = lib.mkOption {
                type = types.listOf types.package;
                description = ''
                  Additional packages passed through to the `buildInputs` of
                  the derivation.

                  Added in: 2.1
                '';
                default = [ ];
              };

              testMain = lib.mkOption {
                description = ''
                  The name of the main Purescript module containing the test suite.

                  Added in: 2.1
                '';
                type = purescriptModule;
              };
            };
          };

          runtime = types.submodule {
            options = {
              enableCtlServer = lib.mkOption {
                description = ''
                  Whether to enable or disable the CTL server (used to apply
                  arguments to scripts and evaluate UPLC). Enabling this will
                  also add the ctl-server overlay.

                  Added in: 2.1
                '';
                type = types.bool;
                default = false;
              };

              extraConfig = lib.mkOption {
                description = ''
                  Additional config options to pass to the CTL runtime. See
                  `runtime.nix` in the CTL flake for a reference of the
                  available options.

                  By default, the runtime is set to use the `preview` network
                  and the same node version that CTL uses in its tests.

                  Added in: 2.1
                '';
                type = types.attrsOf types.anything;
                default = { };
              };
            };
          };

          project = types.submodule {
            options = {
              src = lib.mkOption {
                description = ''
                  Path to the project's source code, including its package.json
                  and package-lock.json files.

                  Added in: 2.1.
                '';
                type = types.path;
              };

              ignoredWarningCodes = lib.mkOption {
                description = ''
                  Warnings from `purs` to silence during compilation.

                  Added in: 2.1
                '';
                default = [ ];
                type = types.listOf types.str;
              };

              shell = lib.mkOption {
                description = ''
                  Options to configure the project's devShell.

                  Added in: 2.1
                '';
                type = shell;
                default = { };
              };

              bundles = lib.mkOption {
                description = ''
                  A map of bundles to be produced for this project.

                  Added in: 2.1
                '';
                type = types.attrsOf bundle;
                default = { };
              };

              plutip = lib.mkOption {
                description = ''
                  Options to configure the project's Plutip suite. If defined,
                  a flake check will be created which runs the tests. 

                  Added in: 2.1
                '';
                type = types.nullOr testConfigs;
                default = null;
              };

              tests = lib.mkOption {
                description = ''
                  Options to configure the project's (non-Plutip) tests. If defined,
                  a flake check will be created which runs the tests.

                  Added in: 2.1
                '';
                type = types.nullOr testConfigs;
                default = null;
              };

              runtime = lib.mkOption {
                description = ''
                  Options to configure CTL's runtime.

                  Added in: 2.1
                '';
                type = runtime;
                default = { };
              };

              enableFormatCheck = lib.mkOption {
                description = ''
                  Whether to add a flake check verifying that the code
                  (including the flake.nix and any JS files in the project) has
                  been formatted.

                  Added in: 2.1
                '';
                type = types.bool;
                default = false;
              };

              enableJsLintCheck = lib.mkOption {
                description = ''
                  Whether to add a check verifying that the JS files in the
                  project have been linted.

                  Added in: 2.1
                '';
                type = types.bool;
                default = false;
              };
            };
          };
        in
        {
          options.offchain = lib.mkOption {
            description = ''
              A CTL project declaration, with arbitrarily many bundles, a
              devShell and optional tests.

              Added in: 2.1
            '';
            type = types.attrsOf project;
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', lib, system, ... }:
      let
        liqwid-nix = self.inputs.liqwid-nix.inputs;
        ctl-overlays = self.inputs.cardano-transaction-lib.overlays;
        projectConfigs = config.offchain;
        utils = import ./utils.nix { inherit pkgs lib; };

        defaultCtlOverlays = with ctl-overlays; [
          purescript
          runtime
        ];

        includeCtlServer =
          lib.any
            (project: project.runtime.enableCtlServer)
            (lib.attrValues projectConfigs);

        additionalOverlays =
          if includeCtlServer
          then [ ctl-overlays.ctl-server ]
          else [ ];

        pkgs = import liqwid-nix.nixpkgs-ctl {
          inherit system;
          overlays = defaultCtlOverlays ++ additionalOverlays;
        };

        # ----------------------------------------------------------------------

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

                  censorCodes = projectConfig.ignoredWarningCodes;

                  shell = {
                    withRuntime = true;
                    packageLockOnly = true;
                    packages = commandLineTools;
                  };
                };
              in
              pkgSet;

            bundles = (lib.mapAttrs
              (name: bundle: project.bundlePursProject {
                inherit (bundle)
                  bundledModuleName
                  webpackConfig;
                inherit name;

                main = bundle.mainModule;
                entrypoint = bundle.entrypointJs;
              })
              projectConfig.bundles);

            bundleChecks =
              lib.mapAttrs'
                (bundleName: _: {
                  name = "${bundleName}_build-check";
                  value = bundles.${bundleName};
                })
                (lib.filterAttrs
                  (_: projectBundle: projectBundle.enableCheck)
                  projectConfig.bundles);

            checks = {
              bundle-checks =
                utils.combineChecks "bundle-checks" bundleChecks;

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

        # ----------------------------------------------------------------------

        projects = lib.mapAttrs makeProject projectConfigs;

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
          all_offchain = utils.combineChecks "all_offchain" projectChecks;
        };

        devShells = lib.mapAttrs (_: project: project.devShell) projects;
      };
  };
}
