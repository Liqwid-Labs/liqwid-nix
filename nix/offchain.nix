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
              main = lib.mkOption {
                description = '' FIXME '';
                type = types.path;
              };

              entrypoint = lib.mkOption {
                description = '' FIXME '';
                type = types.path;
              };
            };
          };

          plutip = types.submodule {
            options = {
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

              shell = lib.mkOption {
                description = '' FIXME '';
                type = shell;
                default = { };
              };

              bundle = lib.mkOption {
                description = '' FIXME '';
                type = bundle;
              };

              plutip = lib.mkOption {
                description = '' FIXME '';
                type = types.nullOr plutip;
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

        pkgs = import self.inputs.nixpkgs-ctl {
          inherit system;
          overlays =
            [
              self.inputs.cardano-transaction-lib.overlays.purescript
              self.inputs.cardano-transaction-lib.overlays.runtime
              self.inputs.cardano-transaction-lib.overlays.ctl-server
            ];
        };

        utils = import ./lib.nix { inherit pkgs lib; };

        makeProject = projectName: projectConfig:
          let
            defaultCommandLineTools = with pkgs; [
              nodePackages.eslint
              nodePackages.prettier
              easy-ps.purs-tidy
              nixpkgs-fmt
            ];

            commandLineTools =
              defaultCommandLineTools
              ++ projectConfig.shell.extraCommandLineTools;

            project =
              let pkgSet = pkgs.purescriptProject {
                inherit (projectConfig)
                  src
                  packageJSON;

                inherit projectName;

                # FIXME: is it worth exposing these?
                # packageJSON = ./package.json;
                # packageLock = ./package-lock.json;

                shell = {
                  withRuntime = true;
                  packageLockOnly = true;
                  packages = commandLineTools;
                };
              };
              in pkgSet;

            checks = {
              plutip-test =
                lib.ifEnable
                  (projectConfig ? plutip)
                  (project.runPlutipTest {
                    inherit (projectConfig.plutip) testMain;
                  });

              formatting-check =
                lib.ifEnable
                  projectConfig.enableFormatCheck
                  (pkgs.runCommand "formatting-check"
                    {
                      nativeBuildInputs = [
                        pkgs.fd
                      ] ++ commandLineTools;
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
                      nativeBuildInputs = [
                        pkgs.fd
                      ] ++ commandLineTools;
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
              web-bundle = project.bundlePursProject {
                main = projectConfig.bundle.main;
                entrypoint = projectConfig.bundle.entrypoint;
              };

              ctl-runtime = pkgs.buildCtlRuntime ctlRuntimeConfig { };
            };

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
