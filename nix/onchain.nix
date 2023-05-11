# TODO: on-chain Plutarch project configuration module.
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
          ghc = types.submodule {
            options = {
              version = lib.mkOption {
                description = ''
                  The version name of GHC to use.

                  Examples: ghc923, ghc925, ghc8107.

                  Added in: 2.0.0.
                '';
                default = "ghc925";
                type = types.str;
              };

              extensions = lib.mkOption {
                type = types.listOf types.str;
                default = [
                  "QuasiQuotes"
                  "TemplateHaskell"
                  "TypeApplications"
                  "ImportQualifiedPost"
                  "PatternSynonyms"
                  "OverloadedRecordDot"
                ];
                description = ''
                  The list of extensions to use with the project.
                  List them out without the '-X' prefix.

                  Example: [ "TypeApplications" "QualifiedDo" ]

                  Added in: 2.0.0.
                '';
              };
            };
          };

          fourmolu = types.submodule {
            options = {
              package = lib.mkPackageOption pkgs "fourmolu" {
                default = [ "haskell" "packages" "ghc924" "fourmolu_0_9_0_0" ];
              };
            };
          };

          applyRefact = types.submodule {
            options = {
              package = lib.mkPackageOption pkgs "apply-refact" {
                default = [ "haskell" "packages" "ghc924" "apply-refact_0_10_0_0" ];
              };
            };
          };

          hlint = types.submodule {
            options = {
              package = lib.mkPackageOption pkgs "hlint" {
                default = [ "haskell" "packages" "ghc924" "hlint" ];
              };
            };
          };

          cabalFmt = types.submodule {
            options = {
              package = lib.mkPackageOption pkgs "cabal-fmt" {
                default = [ "haskellPackages" "cabal-fmt" ];
              };
            };
          };

          hasktags = types.submodule {
            options = {
              package = lib.mkPackageOption pkgs "hasktags" {
                default = [ "haskell" "packages" "ghc924" "hasktags" ];
              };
            };
          };

          shell = types.submodule {
            options = {
              extraCommandLineTools = lib.mkOption {
                type = types.listOf types.package;
                description = ''
                  List of extra packages to make available to the shell.

                  Added in: 2.0.0.
                '';
                default = [ ];
              };
            };
          };

          hoogleImage = types.submodule {
            options = {
              enable = lib.mkOption {
                type = types.bool;
                description = ''
                  Whether or not to expose a docker image bundling the hoogle server with the packages available.

                  Added in: 2.5.0.
                '';
                default = false;
              };

              hoogleDirectory = lib.mkOption {
                type = types.nullOr types.path;
                description = ''
                  Path to copy hoogle data dir from.

                  Added in: 2.5.0.
                '';
                default = null;
              };
            };
          };

          project = types.submodule {
            options = {
              src = lib.mkOption {
                description = ''
                  The source code of the project

                  Added in: 2.0.0.
                '';
                type = types.path;
              };
              ghc = lib.mkOption {
                description = ''
                  GHC-related options for the on-chain build.

                  Added in: 2.0.0.
                '';
                type = ghc;
              };

              fourmolu = lib.mkOption {
                description = ''
                  Fourmolu-related options for the on-chain build.

                  Added in: 2.2.0
                '';
                type = fourmolu;
              };

              applyRefact = lib.mkOption {
                description = ''
                  Apply-refact-related options for the on-chain build.

                  Added in: 2.2.0
                '';
                type = applyRefact;
              };

              hlint = lib.mkOption {
                description = ''
                  HLint-related options for the on-chain build.

                  Added in: 2.2.0
                '';
                type = hlint;
              };

              cabalFmt = lib.mkOption {
                description = ''
                  Cabal-fmt-related options for the on-chain build.

                  Added in: 2.2.0
                '';
                type = cabalFmt;
              };

              hasktags = lib.mkOption {
                description = ''
                  Hasktags-related options for the on-chain build.

                  Added in: 2.2.0
                '';
                type = hasktags;
              };

              shell = lib.mkOption {
                description = ''
                  Options for the dev shell.

                  Added in: 2.0.0.
                '';
                type = shell;
              };

              hoogleImage = lib.mkOption {
                description = ''
                  Options for the hoogle image.

                  Added in: 2.5.0.
                '';
                type = hoogleImage;
              };


              enableHaskellFormatCheck = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to check for Haskell formatting correctness.

                  This will use the Haskell extensions configured in `ghc.extensions`.

                  Added in: 2.0.0.
                '';
              };

              enableCabalFormatCheck = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to check for Cabal formatting correctness.

                  Added in: 2.0.0.
                '';
              };

              enableBuildChecks = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to enable adding the package builds to checks.

                  This is useful if you want to ensure package builds which are not tested by any tests.

                  Added in: 2.0.0.
                '';
              };

              extraHackageDeps = lib.mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of packages to add to the hackage provided to haskell.nix.

                  These are packages that are not available on the public hackage and are
                  manually sourced by your inputs.

                  Added in: 2.0.0.
                '';
              };
            };
          };
        in
        {
          options.onchain = lib.mkOption {
            description = "On-chain project declaration";
            type = types.attrsOf project;
            default = { };
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        liqwid-nix = self.inputs.liqwid-nix.inputs;

        pkgs = import liqwid-nix.nixpkgs {
          inherit system;
          overlays =
            [
              liqwid-nix.haskell-nix.overlay
              (import "${liqwid-nix.iohk-nix}/overlays/crypto")
            ];
        };

        inherit (pkgs) haskell-nix;

        utils = import ./utils.nix { inherit pkgs lib; };
        hackageUtils = import ./mk-hackage.nix { inherit liqwid-nix system pkgs lib; };
        makeProject = projectName: projectConfig:
          let

            pkgs-latest = import liqwid-nix.nixpkgs-latest { inherit system; };
            pkgs = import liqwid-nix.nixpkgs { inherit system; };

            fourmolu = projectConfig.fourmolu.package;
            applyRefact = projectConfig.applyRefact.package;
            hlint = projectConfig.hlint.package;
            nixpkgsFmt = pkgs.nixpkgs-fmt;
            cabalFmt = projectConfig.cabalFmt.package;
            hasktags = projectConfig.hasktags.package;

            ghc = pkgs.haskell.compiler.${projectConfig.ghc.version};

            nonReinstallablePkgs = [
              "array"
              "array"
              "base"
              "binary"
              "bytestring"
              "Cabal"
              "containers"
              "deepseq"
              "directory"
              "exceptions"
              "filepath"
              "ghc"
              "ghc-bignum"
              "ghc-boot"
              "ghc-boot"
              "ghc-boot-th"
              "ghc-compact"
              "ghc-heap"
              "ghcjs-prim"
              "ghcjs-th"
              "ghc-prim"
              "ghc-prim"
              "hpc"
              "integer-gmp"
              "integer-simple"
              "mtl"
              "parsec"
              "pretty"
              "process"
              "rts"
              "stm"
              "template-haskell"
              "terminfo"
              "text"
              "time"
              "transformers"
              "unix"
              "Win32"
              "xhtml"
            ];

            hackageDeps = [
              "${liqwid-nix.plutarch}"
              "${liqwid-nix.plutarch}/plutarch-extra"
            ] ++ projectConfig.extraHackageDeps;

            customHackages =
              hackageUtils.mkHackage
                projectConfig.ghc.version
                hackageDeps;

            haskellModules = [
              # From mlabs-tooling.nix
              (
                let
                  responseFile = builtins.toFile "response-file" ''
                    --optghc=-XFlexibleContexts
                    --optghc=-Wwarn
                    --optghc=-fplugin-opt=PlutusTx.Plugin:defer-errors
                  '';
                  l = [
                    "cardano-binary"
                    "cardano-crypto-class"
                    "cardano-crypto-praos"
                    "cardano-prelude"
                    "heapwords"
                    "measures"
                    "strict-containers"
                    "cardano-ledger-byron"
                    "cardano-slotting"
                  ];
                in
                {
                  packages = builtins.listToAttrs (builtins.map
                    (name: {
                      inherit name;
                      value.components.library.setupHaddockFlags = [ "--haddock-options=@${responseFile}" ];
                      value.components.library.ghcOptions = [ "-XFlexibleContexts" "-Wwarn" "-fplugin-opt=PlutusTx.Plugin:defer-errors" ];
                      value.components.library.extraSrcFiles = [ responseFile ];
                    })
                    l);
                }
              )
              ({ config, pkgs, hsPkgs, ... }: {
                inherit nonReinstallablePkgs;
                packages = {
                  cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf pkgs.secp256k1 ] ];
                  cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
                  plutus-simple-model.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
                };
              })
            ];

            commandLineTools =
              [
                pkgs-latest.cabal-install
                cabalFmt
                fourmolu
                nixpkgsFmt
                hasktags
                pkgs-latest.fd
                pkgs-latest.entr
                applyRefact
              ] ++ projectConfig.shell.extraCommandLineTools;

            project =
              let
                hackages = customHackages;
                pkgSet = haskell-nix.cabalProject' {
                  inherit (projectConfig) src;
                  compiler-nix-name = projectConfig.ghc.version;
                  shell = {
                    withHoogle = true;
                    exactDeps = true;
                    tools = {
                      hlint = { };
                      haskell-language-server = { };
                    };
                    nativeBuildInputs = commandLineTools;
                    shellHook = ''
                      liqwid(){ c=$1; shift; nix run .#$c -- $@; }
                    ''
                    + config.pre-commit.installationScript;
                  };

                  inputMap."https://input-output-hk.github.io/ghc-next-packages" = "${liqwid-nix.ghc-next-packages}";

                  modules = hackages.modules ++ haskellModules;
                  extra-hackages = hackages.extra-hackages;
                  extra-hackage-tarballs = hackages.extra-hackage-tarballs;
                  cabalProjectLocal =
                    ''
                      repository ghc-next-packages
                        url: https://input-output-hk.github.io/ghc-next-packages
                        secure: True
                        root-keys:
                        key-threshold: 0

                      allow-newer:
                        *:base,
                        *:containers,
                        *:directory,
                        *:time,
                        *:bytestring,
                        *:aeson,
                        *:protolude,
                        *:template-haskell,
                        *:ghc-prim,
                        *:ghc,
                        *:cryptonite,
                        *:formatting,
                        monoidal-containers:aeson,
                        size-based:template-haskell,
                        snap-server:attoparsec,
                      --  tasty-hedgehog:hedgehog,
                        *:hashable,
                        *:text

                      constraints:
                        text >= 2
                        , aeson >= 2
                        , dependent-sum >= 0.7
                        , protolude >= 0.3.2
                        , nothunks >= 0.1.3

                      package nothunks
                        flags: +vector +bytestring +text
                    '';
                };
              in
              pkgSet;

            flake = project.flake { };

            buildChecks =
              if projectConfig.enableBuildChecks then
                (
                  pkgs-latest.lib.mapAttrs'
                    (name: value: {
                      name = "build:" + name;
                      inherit value;
                    })
                    flake.packages
                )
              else
                { };

            haskellFormatCheck =
              let
                extStr =
                  builtins.concatStringsSep " " (builtins.map (x: "-o -X" + x) projectConfig.ghc.extensions);
              in
              if projectConfig.enableHaskellFormatCheck then
                {
                  haskellFormatCheck = utils.shellCheck
                    "haskellFormatCheck"
                    projectConfig.src
                    {
                      nativeBuildInputs = [ fourmolu ];
                    }
                    ''
                      find -name '*.hs' \
                        -not -path './dist*/*' \
                        -not -path './haddock/*' \
                          | xargs fourmolu ${extStr} -m check
                    '';
                }
              else
                { };

            cabalFormatCheck =
              if projectConfig.enableCabalFormatCheck then
                {
                  cabalFormatCheck = utils.shellCheck
                    "cabalFormatCheck"
                    projectConfig.src
                    {
                      nativeBuildInputs = [ cabalFmt ];
                    }
                    ''
                      find -name '*.cabal' -not -path './dist*/*' -not -path './haddock/*' | xargs cabal-fmt -c
                    '';
                }
              else
                { };

            hoogleImage =
              if projectConfig.hoogleImage.enable then
                {
                  hoogleImage = import ./hoogle.nix
                    {
                      inherit pkgs lib project;
                      inherit (projectConfig.hoogleImage) hoogleDirectory;
                      hoogle = assert (lib.assertMsg (self.inputs ? hoogle) ''
                        [liqwid-nix]: liqwid-nix onchain module is using hoogle. Please provide a 'hoogle' input.

                        This input should be taken from https://github.com/ndmitchell/hoogle.
                      ''); self.inputs.hoogle;
                    };
                }
              else
                { };

            packages = flake.packages // hoogleImage;

            checks =
              lib.fold lib.mergeAttrs { }
                [
                  flake.checks
                  buildChecks
                  haskellFormatCheck
                  cabalFormatCheck
                ];

            haskellSources = "$(git ls-tree -r HEAD --full-tree --name-only | grep '.\\+\\.hs')";
            cabalSources = "$(git ls-tree -r HEAD --full-tree --name-only | grep '.\\+\\.cabal')";
          in
          {
            devShell = flake.devShell;

            inherit checks packages;

            check = utils.combineChecks "combined-checks" checks;


            run.nixFormat =
              {
                dependencies = [ nixpkgsFmt ];
                script = ''
                  find . -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' -exec nixpkgs-fmt {} +
                '';
                groups = [ "format" "precommit" ];
                help = ''
                  echo "  Formats nix files using nixpkgs-fmt."
                '';
              };
            run.haskellFormat =
              let
                arguments = builtins.concatStringsSep " " (builtins.map (extension: "-o -X" + extension) projectConfig.ghc.extensions);
              in
              {
                dependencies = [ fourmolu cabalFmt ];
                script = ''
                  # shellcheck disable=SC2046
                  fourmolu ${arguments} -m inplace ${haskellSources}
                  # shellcheck disable=SC2046
                  cabal-fmt -i ${cabalSources}
                '';
                groups = [ "format" "precommit" ];
                help = ''
                  echo "  Runs fourmolu and cabal-fmt."
                  echo
                  echo "  fourmolu: A formatter for Haskell source code."
                  echo "  cabal-fmt: Format .cabal files preserving the original field ordering, and comments."
                  echo
                  echo "  Fourmolu is using the following Haskell extensions:"
                  echo "${builtins.concatStringsSep "\n" (builtins.map (p: "  - " + p) projectConfig.ghc.extensions)}"
                  echo
                  echo "  NOTE: You can change these in the flake module!"
                '';
              };
            run.haskellLint =
              let
                arguments = builtins.concatStringsSep " " (builtins.map (extension: " -X" + extension) projectConfig.ghc.extensions);
              in
              {
                dependencies = [ hlint ];
                script = ''
                  # shellcheck disable=SC2046
                  hlint ${arguments} ${haskellSources}
                '';
                groups = [ "lint" "precommit" ];
                help = ''
                  echo "  hlint: HLint gives hints on how to improve Haskell code."
                '';
              };
            run.hasktags =
              {
                dependencies = [ hasktags ];
                script = ''
                  # shellcheck disable=SC2046
                  hasktags -x ${haskellSources}
                '';
                help = ''
                  echo '  hasktags: Produces ctags "tags" and etags "TAGS" files for Haskell programs.'
                '';
              };
            run.hoogle =
              {
                dependencies = project.shell.nativeBuildInputs;
                script = ''
                  hoogle server --local -p 8080 >/dev/null
                '';
                help = ''
                  echo '  Run a hoogle server with the local packages on port 8080.'
                '';
              };
          };

        projects = lib.mapAttrs makeProject config.onchain;

        projectPackages =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.packages)
              projects);

        projectChecks =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.checks // { all = project.check; })
              projects);

        projectScripts =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.run)
              projects);

        moduleUsed = projectChecks != { };
      in
      {
        devShells =
          lib.mapAttrs
            (_: project: project.devShell)
            projects;

        packages = projectPackages;

        run = projectScripts;

        checks = (projectChecks // (if moduleUsed then {
          all_onchain = utils.combineChecks "all_onchain" projectChecks;
        } else { }));
      };
  };
}
