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
          ghc = types.submodule {
            options = {
              version = lib.mkOption {
                description = ''
                  The version name of GHC to use.

                  Examples: ghc923, ghc924, ghc8107.

                  Added in: 2.0.
                '';
                default = "ghc923";
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

                  Added in: 2.0.
                '';
              };
            };
          };

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

          project = types.submodule {
            options = {
              src = lib.mkOption {
                description = ''
                  The source code of the project

                  Added in: 2.0.
                '';
                type = types.path;
              };
              ghc = lib.mkOption {
                description = ''
                  GHC-related options for the on-chain build.

                  Added in: 2.0.
                '';
                type = ghc;
              };

              shell = lib.mkOption {
                description = ''
                  Options for the dev shell.

                  Added in: 2.0.
                '';
                type = shell;
              };

              enableHaskellFormatCheck = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to check for Haskell formatting correctness.

                  This will use the Haskell extensions configured in `ghc.extensions`.

                  Added in: 2.0.
                '';
              };

              enableCabalFormatCheck = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to check for Cabal formatting correctness.

                  Added in: 2.0.
                '';
              };

              enableBuildChecks = lib.mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether or not to enable adding the package builds to checks.

                  This is useful if you want to ensure package builds which are not tested by any tests.

                  Added in: 2.0.
                '';
              };

              extraHackageDeps = lib.mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of packages to add to the hackage provided to haskell.nix.

                  These are packages that are not available on the public hackage and are
                  manually sourced by your inputs.

                  Added in: 2.0.
                '';
              };

            };
          };
        in
        {
          options.onchain = lib.mkOption {
            description = "On-chain project declaration";
            type = types.attrsOf project;
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        pkgs = import self.inputs.nixpkgs {
          inherit system;
          overlays =
            [
              self.inputs.haskell-nix.overlay
              (import "${self.inputs.iohk-nix}/overlays/crypto")
            ];
        };

        utils = import ./utils.nix { inherit pkgs lib; };
        makeProject = projectName: projectConfig:
          let

            pkgs-latest = import self.inputs.nixpkgs-latest { inherit system; };
            pkgs2205 = import self.inputs.nixpkgs-2205 { inherit system; };

            fourmolu = pkgs-latest.haskell.packages.ghc924.fourmolu_0_8_2_0;
            applyRefact = pkgs2205.haskell.packages.ghc922.apply-refact_0_10_0_0;
            hlint = pkgs2205.haskell.packages.ghc923.hlint;
            nixpkgsFmt = pkgs2205.nixpkgs-fmt;
            cabalFmt = pkgs-latest.haskellPackages.cabal-fmt;
            hasktags = pkgs2205.haskell.packages.ghc923.hasktags;

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
              "${self.inputs.plutarch.inputs.flat}"
              "${self.inputs.plutarch.inputs.protolude}"
              "${self.inputs.plutarch.inputs.cardano-prelude}/cardano-prelude"
              "${self.inputs.plutarch.inputs.cardano-crypto}"
              "${self.inputs.plutarch.inputs.cardano-base}/binary"
              "${self.inputs.plutarch.inputs.cardano-base}/cardano-crypto-class"
              "${self.inputs.plutarch.inputs.plutus}/plutus-core"
              "${self.inputs.plutarch.inputs.plutus}/plutus-ledger-api"
              "${self.inputs.plutarch.inputs.plutus}/plutus-tx"
              "${self.inputs.plutarch.inputs.plutus}/prettyprinter-configurable"
              "${self.inputs.plutarch.inputs.plutus}/word-array"
              "${self.inputs.plutarch.inputs.secp256k1-haskell}"
              "${self.inputs.plutarch.inputs.plutus}/plutus-tx-plugin" # necessary for FFI tests
              "${self.inputs.plutarch}"
              "${self.inputs.plutarch}/plutarch-extra"
            ] ++ projectConfig.extraHackageDeps;

            customHackages =
              self.inputs.haskell-nix-extra-hackage.mkHackagesFor system
                projectConfig.ghc.version
                hackageDeps;

            haskellModules = [
              ({ config, pkgs, hsPkgs, ... }: {
                inherit nonReinstallablePkgs; # Needed for a lot of different things
                packages = {
                  cardano-binary.doHaddock = false;
                  cardano-binary.ghcOptions = [ "-Wwarn" ];
                  cardano-crypto-class.components.library.pkgconfig =
                    pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
                  cardano-crypto-class.doHaddock = false;
                  cardano-crypto-class.ghcOptions = [ "-Wwarn" ];
                  cardano-crypto-praos.components.library.pkgconfig =
                    pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
                  cardano-prelude.doHaddock =
                    false; # somehow above options are not applied?
                  cardano-prelude.ghcOptions = [ "-Wwarn" ];
                  # Workaround missing support for build-tools:
                  # https://github.com/input-output-hk/haskell.nix/issues/231
                  plutarch-test.components.exes.plutarch-test.build-tools =
                    [ config.hsPkgs.hspec-discover ];
                };
              })
            ];

            hls' =
              pkgs.haskell-nix.cabalProject' {
                modules = [{
                  inherit nonReinstallablePkgs;
                  reinstallableLibGhc = false;
                }];
                compiler-nix-name = projectConfig.ghc.version;
                src = "${self.inputs.haskell-language-server}";
                sha256map."https://github.com/pepeiborra/ekg-json"."7a0af7a8fd38045fd15fb13445bdcc7085325460" =
                  "fVwKxGgM0S4Kv/4egVAAiAjV7QB5PBqMVMCfsv7otIQ=";
              };
            hls =
              hls'.hsPkgs.haskell-language-server.components.exes.haskell-language-server;

            commandLineTools =
              [
                pkgs-latest.cabal-install
                hlint
                cabalFmt
                fourmolu
                nixpkgsFmt
                hasktags
                hls
                pkgs-latest.fd
                pkgs-latest.entr
                applyRefact
              ] ++ projectConfig.shell.extraCommandLineTools;

            project =
              let
                hackages = customHackages;
                pkgSet = pkgs.haskell-nix.cabalProject' {
                  inherit (projectConfig) src;
                  compiler-nix-name = projectConfig.ghc.version;
                  shell = {
                    withHoogle = true;
                    exactDeps = true;
                    nativeBuildInputs = commandLineTools;
                  };
                  modules = haskellModules ++ hackages.modules;
                  extra-hackages = hackages.extra-hackages;
                  extra-hackage-tarballs = hackages.extra-hackage-tarballs;
                  cabalProjectLocal =
                    ''
                      allow-newer:
                        *:base
                        , canonical-json:bytestring
                        , plutus-core:ral
                        , plutus-core:some
                        , inline-r:singletons
                    '';
                };
              in
              pkgSet;

            flake = project.flake { };

            buildChecks =
              lib.ifEnable projectConfig.enableBuildChecks (
                pkgs-latest.lib.mapAttrs'
                  (name: value: {
                    name = "build:" + name;
                    inherit value;
                  })
                  flake.packages
              );

            haskellFormatCheck =
              let extStr =
                builtins.concatStringsSep " " (builtins.map (x: "-o -X" + x) projectConfig.ghc.extensions);
              in
              lib.ifEnable projectConfig.enableHaskellFormatCheck {
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
              };

            cabalFormatCheck =
              lib.ifEnable projectConfig.enableCabalFormatCheck
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
                };

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

            inherit checks;

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
              {
                dependencies = [ hlint ];
                script = ''
                  # shellcheck disable=SC2046
                  hlint -XQuasiQuotes ${haskellSources}
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
                  hasktags -x ${haskellSources}
                '';
                help = ''
                  echo '  hasktags: Produces ctags "tags" and etags "TAGS" files for Haskell programs.'
                '';
              };
          };

        projects = lib.mapAttrs makeProject config.onchain;

        projectChecks =
          utils.flat2With (project: check: project + "_" + check)
            (lib.mapAttrs
              (_: project: project.checks // { all = project.check; })
              projects);

        projectScripts =
          utils.flat2With (project: script: project + "_" + script)
            (lib.mapAttrs
              (_: project: project.run)
              projects);
      in
      {
        devShells =
          lib.mapAttrs
            (_: project: project.devShell)
            projects;

        run = projectScripts;

        checks = projectChecks // {
          all_onchain = utils.combineChecks "all_onchain" projectChecks;
        };
      };
  };
}
