{
  description = "Nix tools for building Liqwid projects";

  # Inputs
  # 
  # We should aim to have as few inputs here as possible, as
  # the way liqwid-nix is set up is more conducive to having
  # callers pass their own inputs through the arguments.
  #
  # For nixpkgs, however, where we are undoubtedly depending
  # on a specific release, we can have those here, in the
  # naming format of `nixpkgs-<version>`.
  #
  # @since 1.0.0
  inputs.nixpkgs-2205.url = "github:NixOS/nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs-2205, nixpkgs }: rec {
    # Build a project given overlays.
    #
    # The idea is that this lives at the top level of a flake:
    #
    # ```nix 
    # outputs = inputs@{ liqwid-nix, ... }:
    #   (liqwid-nix.buildProject
    #     {
    #       inherit inputs;
    #       src = ./.;
    #     }
    #     [
    #       liqwid-nix.haskellProject
    #       (liqwid-nix.addDependencies [
    #         "${inputs.my-hackage-dependency}"
    #       ])
    #     ]
    #   ).toFlake;
    # ```
    #
    # ### Guidelines for writing overlays
    # 
    # An overlay is a function like `(self: super: ...)`.
    # Inside of it, you are able to override any attributes that have been 
    # previously defined. In order to reuse attributes that have been provided,
    # you can use the 'self' argument, which has the fully resolved output. However,
    # you should be careful to not reference anything that you define in the overlay.
    # See this blog post for more information on how to write overlays:
    # https://blog.flyingcircus.io/2017/11/07/nixos-the-dos-and-donts-of-nixpkgs-overlays/
    #
    # Inside of this particular overlay system, there are a couple of expected attributes:
    # - 'args' will be the arguments provided by the caller of 'buildProject'. 
    # - 'inputs' will be the inputs provided through 'args'.
    # - 'toFlake' is expected to be what the flake will eventually resolve to
    #
    # Other attribute conventions may happen as result of using overlays.
    #
    # @since 1.0.0
    buildProject =
      args@{ inputs
      , supportedSystems ? inputs.nixpkgs-latest.lib.systems.flakeExposed
      , ghcVersion ? "ghc923"
      , ...
      }:
      overlays:
      let
        base = {
          inherit args;
          inherit ghcVersion;
          inherit supportedSystems;
          inherit (args) inputs;

        };
        baseOverlays = [
          (self: super: {
            perSystem = self.inputs.nixpkgs.lib.genAttrs supportedSystems;

            nixpkgsOverlays = [ ];

            pkgsFor = system:
              import self.inputs.nixpkgs {
                inherit system;
                overlays = self.nixpkgsOverlays;
              };
            pkgsFor' = system:
              import self.inputs.nixpkgs-latest { inherit system; };

            nixpkgs2205for = system: import nixpkgs-2205 { inherit system; };
          })
        ];

        # This is the overlay fixpoint pattern:
        # "resolved" here, is "self", or the fully resolved 
        # output of applying all the overlays. Due to
        # laziness, we get to do this trick, and each of
        # the overlays individually gets access to the
        # eventual result.
        #
        # For further reading on this, see this blog post:
        # https://blog.layus.be/posts/2020-06-12-nix-overlays.html
        #
        # @since 1.0.0
        resolved =
          builtins.foldl' (super: overlay: super // overlay resolved super) base
            (baseOverlays ++ overlays);
      in
      resolved;

    # Haskell project overlay.
    # 
    # Use this in order to create haskell projects using cabal.
    # Keep in mind, a number of inputs will need to be provided, including:
    # - haskell-nix-extra-hackage
    # - iohk-nix
    # - haskell-nix
    # - nixpkgs
    # - nixpkgs-2205
    # - nixpkgs-latest, which is a *later* version of nixpkgs.
    # - haskell-language-server
    #
    # @since 1.0.0
    haskellProject = self: super:
      let
        inherit (self)
          inputs nixpkgs nixpkgs-latest haskell-nix pkgsFor pkgsFor';
      in
      {
        fourmoluFor = system:
          (self.pkgsFor' system).haskell.packages.ghc924.fourmolu_0_9_0_0;
        applyRefactFor = system:
          (self.nixpkgs2205for
            system).haskell.packages.ghc922.apply-refact_0_10_0_0;
        hlintFor = system:
          (self.nixpkgs2205for system).haskell.packages.ghc923.hlint;
        nixpkgsFmtFor = system: (self.nixpkgs2205for system).nixpkgs-fmt;
        cabalFmtFor = system: (self.pkgsFor' system).haskellPackages.cabal-fmt;
        hasktagsFor = system: (self.nixpkgs2205for system).haskell.packages.ghc923.hasktags;

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
          # "ghci"
          # "haskeline"
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

        hackageDeps = super.hackageDeps or [ ];

        customHackages = system: compiler-nix-name:
          inputs.haskell-nix-extra-hackage.mkHackagesFor system
            compiler-nix-name
            self.hackageDeps;

        haskellModules = super.haskellModules or [ ];

        applyDep = pkgs: o:
          let
            h = self.customHackages pkgs.system o.compiler-nix-name;
            o' = (super.applyDep or (p: o: o)) pkgs o;
          in
          o' // rec {
            modules = self.haskellModules ++ h.modules ++ (o.modules or [ ]);
            extra-hackages = h.extra-hackages ++ (o.extra-hackages or [ ]);
            extra-hackage-tarballs = h.extra-hackage-tarballs
            // (o.extra-hackage-tarballs or { });
            cabalProjectLocal = o'.cabalProjectLocal or "";
          };

        nixpkgsOverlays = super.nixpkgsOverlays ++ [
          inputs.haskell-nix.overlay
          (import "${inputs.iohk-nix}/overlays/crypto")
        ];

        hlsFor' = compiler-nix-name: pkgs:
          pkgs.haskell-nix.cabalProject' {
            modules = [{
              inherit (self) nonReinstallablePkgs;
              reinstallableLibGhc = false;
            }];
            inherit compiler-nix-name;
            src = "${inputs.haskell-language-server}";
            sha256map."https://github.com/pepeiborra/ekg-json"."7a0af7a8fd38045fd15fb13445bdcc7085325460" =
              "fVwKxGgM0S4Kv/4egVAAiAjV7QB5PBqMVMCfsv7otIQ=";
          };
        hlsFor = compiler-nix-name: system:
          let
            pkgs = pkgsFor system;
            oldGhc = "8107";
          in
          if (compiler-nix-name == "ghc${oldGhc}") then
            pkgs.haskell-language-server.override
              {
                supportedGhcVersions = [ oldGhc ];
              }
          else
            (self.hlsFor' compiler-nix-name
              pkgs).hsPkgs.haskell-language-server.components.exes.haskell-language-server;

        commandLineTools = system:
          let
            pkgs' = pkgsFor' system;
            sup = super.commandLineTools or (system: [ ]);
          in
          (sup system) ++ [
            pkgs'.cabal-install
            (self.hlintFor system)
            (self.cabalFmtFor system)
            (self.fourmoluFor system)
            (self.nixpkgsFmtFor system)
            (self.hasktagsFor system)
            (self.hlsFor self.ghcVersion system)
            pkgs'.fd
            pkgs'.entr
            (self.applyRefactFor system)
          ];

        projectForGhc = compiler-nix-name: system:
          let
            pkgs = pkgsFor system;
            pkgs' = pkgsFor' system;
            pkgSet = pkgs.haskell-nix.cabalProject' (self.applyDep pkgs {
              src = self.args.src;
              inherit compiler-nix-name;
              modules = [ ];
              shell = {
                withHoogle = true;
                exactDeps = true;
                nativeBuildInputs = self.commandLineTools system;
              };
            });
          in
          pkgSet;

        projectFor = self.projectForGhc self.ghcVersion;

        toFlake =
          let inherit (self) perSystem projectFor;
          in
          (super.toFlake or { }) // {
            project = perSystem projectFor;

            flake = perSystem (system: (projectFor system).flake { });

            packages =
              perSystem (system: self.toFlake.flake.${system}.packages // { });

            checks = perSystem (system: self.toFlake.flake.${system}.checks);

            check = perSystem (system:
              (pkgsFor system).runCommand "combined-test"
                {
                  checksss = builtins.attrValues self.toFlake.checks.${system};
                } ''
                echo $checksss
                touch $out
              '');
            devShell = perSystem (system: self.toFlake.flake.${system}.devShell);
          };
      };

    # Add extra command line tools to the shell.
    # 
    # @since 1.0.0
    addCommandLineTools = addF: self: super: {
      commandLineTools = system:
        let
          pkgs = self.pkgsFor system;
          pkgs' = self.pkgsFor' system;
          sup = super.commandLineTools or (_: [ ]);
        in
        (sup system) ++ (addF pkgs pkgs');
    };

    # Add input-based dependencies to hackage deps
    #
    # @since 1.0.0
    addDependencies = addedDependencies: self: super: {
      hackageDeps = (super.hackageDeps or [ ]) ++ addedDependencies;
    };

    # Add all packages to checks, as a result, running `nix build .#check.${system}`
    # will be a superset of `nix build`. Prefixing "build:" to package name to 
    # avoid overwriting the existing checks.
    #
    # @since 1.0.0
    addBuildChecks = self: super:
      let
        inherit (self) perSystem pkgsFor';
        flake = (super.toFlake or { });
        prefixPackages = system:
          (pkgsFor' system).lib.mapAttrs' (name: value: {
            name = "build:" + name;
            inherit value;
          });
      in
      {
        toFlake = flake // {
          checks = self.perSystem (system:
            (prefixPackages system flake.packages.${system})
              // flake.checks.${system});
        };
      };

    # Add a check that runs a shell script with some packages in its
    # executing environment.
    #
    # Like addShellCheck but isn't passed `system`.
    #
    # @since 1.0.0
    addShellCheck = name: package: addShellCheck' name (_: package);

    # Add a check that runs a shell script with some packages in its
    # executing environment.
    #
    # @since 1.0.0
    addShellCheck' = name: package: exec: self: super: {
      toFlake =
        let
          inherit (self) inputs perSystem pkgsFor';
          flake = super.toFlake or { };
        in
        flake // {
          checks = perSystem (system:
            flake.checks.${system} // {
              ${name} =
                let pkgs' = pkgsFor' system;
                in
                pkgs'.runCommand name
                  {
                    nativeBuildInputs = [ (package system pkgs') ];
                  } ''
                  export LC_CTYPE=C.UTF-8
                  export LC_ALL=C.UTF-8
                  export LANG=C.UTF-8
                  cd ${inputs.self}
                  ${exec}
                  mkdir $out
                '';
            });
        };
    };

    # Add a script that can be run using `nix run`.
    #
    # The `exec` argument is supplied with `self` and `system`,
    # so that it can get packages from inside the context.
    #
    # @since 1.1.0
    addRunScript = name: exec: self: super: {
      toFlake =
        let
          inherit (self) inputs perSystem pkgsFor';
          flake = super.toFlake or { };
        in
        flake // {
          apps = perSystem
            (system:
              let
                pkgs = pkgsFor' system;
                script = pkgs.writeScriptBin name ''
                  export LC_CTYPE=C.UTF-8
                  export LC_ALL=C.UTF-8
                  export LANG=C.UTF-8
                  set -x
                  ${exec self system}
                '';
              in
              (flake.apps.${system} or { }) // {
                ${name} = {
                  type = "app";
                  program = "${script}/bin/${name}";
                };
              }
            );
        };
    };

    # Add common scripts for running using `nix run`.
    #
    # In many ways, this replaces Makefiles. These scripts
    # should be runnable without any extra packages being
    # added to the environment by the user.
    #
    # Packages that are necessary only for the script are
    # inlined using nix inlining.
    #
    # @since 1.1.0
    addCommonRunScripts = self: super:
      let
        haskellSources = "$(git ls-tree -r HEAD --full-tree --name-only | grep '.\\+\\.hs')";
        cabalSources = "$(git ls-tree -r HEAD --full-tree --name-only | grep '.\\+\\.cabal')";
      in
      builtins.foldl' (super': add: add self super') super [
        (addRunScript
          "nixFormat"
          (self: system: ''
            find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs ${self.nixpkgsFmtFor system}/bin/nixpkgs-fmt
          '')
        )
        (addRunScript
          "haskellFormat"
          (self: system:
            let
              arguments = builtins.concatStringsSep " " (builtins.map (extension: "-o -X" + extension) [
                "QuasiQuotes"
                "TemplateHaskell"
                "TypeApplications"
                "ImportQualifiedPost"
                "PatternSynonyms"
                "OverloadedRecordDot"
              ]);
            in
            ''
              fourmolu ${arguments} -m inplace ${haskellSources}
              cabal-fmt -i ${cabalSources}
            '')
        )
        (addRunScript
          "lint"
          (self: system: ''
            hlint -XQuasiQuotes ${haskellSources}
          ''))
        (addRunScript "tag" (self: system: "${self.hasktagsFor system}/bin/hasktags -x ${haskellSources}"))
        (addRunScript
          "ci"
          (self: system:
            (if system != "x86_64-linux" then (builtins.trace "warning: CI only builds on 'x86_64-linux', you are building on ${system}") else (x: x)) ''
              nix build .#check.${system}
            '')
        )
        (addRunScript
          "hoogle"
          (self: system: ''
            pkill hoogle || true
            hoogle generate --local=haddock --database=hoo/local.hoo
            hoogle server --local -p 8081 >> /dev/null &
            hoogle server --local --database=hoo/local.hoo -p 8082 >> /dev/null &
          '')
        )
      ];

    # Enables running fourmolu on `*.hs` files.
    # Specify the extensions in the first argument.
    #
    # Example:
    # ```
    #   (liqwid-nix.enableFormatCheck [
    #     "-XTemplateHaskell"
    #     "-XOverloadedRecordDot"
    #     "-XTypeApplications"
    #     "-XPatternSynonyms"
    #     "-XNoFieldSelectors"
    #     "-XImportQualifiedPost"
    #   ])
    # ```
    #
    # @since 1.0.0
    enableFormatCheck = exts: self:
      let
        extStr =
          builtins.concatStringsSep " " (builtins.map (x: "-o " + x) exts);
      in
      addShellCheck' "formatCheck"
        (system: _: [ (self.fourmoluFor system) ]) ''
        find -name '*.hs' \
          -not -path './dist*/*' \
          -not -path './haddock/*' \
          | xargs fourmolu ${extStr} -m check
      ''
        self;

    # Enables running hlint on `*.hs` files.
    #
    # @since 1.0.0
    enableLintCheck = self:
      addShellCheck' "lintCheck" (system: _: [ (self.hlintFor system) ]) ''
        find -name '*.hs' -not -path './dist*/*' -not -path './haddock/*' | xargs hlint 
      ''
        self;

    # Enables running cabal-fmt on `*.cabal` files.
    #
    # @since 1.0.0
    enableCabalFormatCheck =
      addShellCheck "cabalFormatCheck" (p: [ p.haskellPackages.cabal-fmt ]) ''
        find -name '*.cabal' -not -path './dist*/*' -not -path './haddock/*' | xargs cabal-fmt -c
      '';

    # Enables running nixpkgs-fmt on `*.nix` files.
    #
    # @since 1.0.0
    enableNixFormatCheck = self:
      addShellCheck' "nixFormatCheck"
        (system: _: [ (self.nixpkgsFmtFor system) ]) ''
        find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt --check
      ''
        self;

    # Plutarch project overlay.
    #
    # @since 1.0.0
    plutarchProject = self: super:
      let
        inherit (self) inputs pkgsFor pkgsFor';
        inherit (inputs) nixpkgs nixpkgs-latest haskell-nix plutarch;
      in
      {
        haskellModules = (super.haskellModules or [ ]) ++ [
          ({ config, pkgs, hsPkgs, ... }: {
            inherit (self)
              nonReinstallablePkgs; # Needed for a lot of different things
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

        applyDep = pkgs: o:
          let
            h = self.customHackages pkgs.system o.compiler-nix-name;
            o' = (super.applyDep or (p: o: o)) pkgs o;
          in
          o' // rec {
            modules = self.haskellModules ++ h.modules ++ (o.modules or [ ]);
            extra-hackages = h.extra-hackages ++ (o.extra-hackages or [ ]);
            extra-hackage-tarballs = h.extra-hackage-tarballs
            // (o.extra-hackage-tarballs or { });
            cabalProjectLocal = o'.cabalProjectLocal or "" + (
              ''
                allow-newer:
                  *:base
                  , canonical-json:bytestring
                  , plutus-core:ral
                  , plutus-core:some
                  , inline-r:singletons
              ''
            );
          };

        hackageDeps = (super.hackageDeps or [ ]) ++ [
          "${inputs.plutarch.inputs.flat}"
          "${inputs.plutarch.inputs.protolude}"
          "${inputs.plutarch.inputs.cardano-prelude}/cardano-prelude"
          "${inputs.plutarch.inputs.cardano-crypto}"
          "${inputs.plutarch.inputs.cardano-base}/binary"
          "${inputs.plutarch.inputs.cardano-base}/cardano-crypto-class"
          "${inputs.plutarch.inputs.plutus}/plutus-core"
          "${inputs.plutarch.inputs.plutus}/plutus-ledger-api"
          "${inputs.plutarch.inputs.plutus}/plutus-tx"
          "${inputs.plutarch.inputs.plutus}/prettyprinter-configurable"
          "${inputs.plutarch.inputs.plutus}/word-array"
          "${inputs.plutarch.inputs.secp256k1-haskell}"
          "${inputs.plutarch.inputs.plutus}/plutus-tx-plugin" # necessary for FFI tests

          "${inputs.plutarch}"
          "${inputs.plutarch}/plutarch-extra"
        ];

      };

    # For developing _this repository_, having nixpkgs-fmt available is convenient.
    #
    # @since 1.0.0
    devShell = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let pkgs = import nixpkgs { inherit system; };
      in
      pkgs.mkShell {
        name = "shell";
        buildInputs = [ pkgs.nixpkgs-fmt ];
      });

    checks = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: {
      nixFormatCheck =
        let pkgs = import nixpkgs { inherit system; };
        in
        pkgs.runCommand "nixFormatCheck"
          {
            nativeBuildInputs = [ ];
            buildInputs = [ pkgs.nixpkgs-fmt ];
          } ''
          export LC_CTYPE=C.UTF-8
          export LC_ALL=C.UTF-8
          export LANG=C.UTF-8
          cd ${self}
          find -name '*.nix' -not -path './dist*/*' -not -path './haddock/*' | xargs nixpkgs-fmt --check
          mkdir $out
        '';
    });
  };
}

