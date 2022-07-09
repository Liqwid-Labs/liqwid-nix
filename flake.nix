{
  description = "Nix tools for building Liqwid projects";

  outputs = { self, nixpkgs }: rec {
    # Build a project given overlays.
    #
    # The idea is that this lives at the top level of a flake:
    #
    # ```nix 
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
    buildProject =
      args@
      { inputs
      , supportedSystems ? inputs.nixpkgs-latest.lib.systems.flakeExposed
      , ghcVersion ? "ghc923"
      , ...
      }: overlays:
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

            pkgsFor = system: import self.inputs.nixpkgs {
              inherit system;
              overlays = self.nixpkgsOverlays;
            };
            pkgsFor' = system: import self.inputs.nixpkgs-latest { inherit system; };
          })
        ];

        # This is the overlay fixpoint pattern:
        # "res" here, is "self", or the fully resolved 
        # output of applying all the overlays. Due to
        # laziness, we get to do this trick, and each of
        # the overlays individually get access to the
        # eventual result.
        resolved =
          builtins.foldl'
            (super: overlay: super // overlay resolved super
            )
            base
            (baseOverlays ++ overlays);
      in
      resolved;


    # Haskell project overlay
    #
    # This provides a number of things including
    # 
    haskellProject =
      self:
      super:
      let
        inherit (self) inputs nixpkgs nixpkgs-latest
          haskell-nix pkgsFor pkgsFor';
      in
      {
        fourmoluFor = system:
          (pkgsFor' system).haskell.packages.ghc922.fourmolu_0_6_0_0;

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
          inputs.haskell-nix-extra-hackage.mkHackagesFor
            system
            compiler-nix-name
            self.hackageDeps;

        extraCabalConstraints = super.extraCabalConstraints or [ ];

        haskellModules = super.haskellModules or [ ];

        applyDep = pkgs: o:
          let
            h = self.customHackages pkgs.system o.compiler-nix-name;
            o' = (super.applyDep or (p: o: o)) pkgs o;

            # The list of cabal constraints to add on top of the local cabal.project
            extraCabalConstraintsStr =
              builtins.concatStringsSep "\n"
                (builtins.map (x: "  , " + x)
                  self.extraCabalConstraints);
          in
          o' // rec {
            modules =
              self.haskellModules ++ h.modules ++ (o.modules or [ ]);
            extra-hackages =
              h.extra-hackages ++ (o.extra-hackages or [ ]);
            extra-hackage-tarballs =
              h.extra-hackage-tarballs // (o.extra-hackage-tarballs or { });
            cabalProjectLocal =
              (o'.cabalProjectLocal or "") + extraCabalConstraintsStr;
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
            sha256map."https://github.com/pepeiborra/ekg-json"."7a0af7a8fd38045fd15fb13445bdcc7085325460" = "fVwKxGgM0S4Kv/4egVAAiAjV7QB5PBqMVMCfsv7otIQ=";
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
            (self.hlsFor' compiler-nix-name pkgs).hsPkgs.haskell-language-server.components.exes.haskell-language-server;

        projectForGhc = compiler-nix-name: system:
          let pkgs = pkgsFor system; in
          let pkgs' = pkgsFor' system; in
          let
            pkgSet = pkgs.haskell-nix.cabalProject' (self.applyDep pkgs {
              src = self.args.src;
              inherit compiler-nix-name;
              modules = [ ];
              shell = {
                withHoogle = true;
                exactDeps = true;
                nativeBuildInputs = [
                  pkgs'.cabal-install
                  pkgs'.hlint
                  pkgs'.haskellPackages.cabal-fmt
                  (self.fourmoluFor system)
                  pkgs'.nixpkgs-fmt
                  (self.hlsFor compiler-nix-name system)
                ];
              };
            });
          in
          pkgSet;

        projectFor = self.projectForGhc self.ghcVersion;

        toFlake =
          let
            inherit (self) perSystem projectFor;
          in
          rec {
            project = perSystem projectFor;
            flake = perSystem (system: (projectFor system).flake { });

            packages = perSystem (system:
              flake.${system}.packages // { });

            # Define what we want to test
            checks = perSystem (system:
              flake.${system}.checks // { });
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



    # Add input-based dependencies to hackage deps
    addDependencies = addedDependencies:
      self: super: {
        hackageDeps = (super.hackageDeps or [ ]) ++ addedDependencies;
      };

    # Plutarch project overlay.
    plutarchProject =
      self:
      super:
      let
        inherit (self) inputs pkgsFor pkgsFor' fourmoluFor;
        inherit (inputs) nixpkgs nixpkgs-latest haskell-nix plutarch;
      in
      {
        haskellModules = super.haskellModules or [
          ({ config, pkgs, hsPkgs, ... }: {
            inherit (self) nonReinstallablePkgs; # Needed for a lot of different things
            packages = {
              cardano-binary.doHaddock = false;
              cardano-binary.ghcOptions = [ "-Wwarn" ];
              cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
              cardano-crypto-class.doHaddock = false;
              cardano-crypto-class.ghcOptions = [ "-Wwarn" ];
              cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
              cardano-prelude.doHaddock = false; # somehow above options are not applied?
              cardano-prelude.ghcOptions = [ "-Wwarn" ];
              # Workaround missing support for build-tools:
              # https://github.com/input-output-hk/haskell.nix/issues/231
              plutarch-test.components.exes.plutarch-test.build-tools = [
                config.hsPkgs.hspec-discover
              ];
            };
          })
        ];


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
        ];

        formatCheckFor = system:
          let
            pkgs' = pkgsFor' system;
          in
          pkgs'.runCommand "format-check"
            {
              nativeBuildInputs = [ pkgs'.haskellPackages.cabal-fmt pkgs'.nixpkgs-fmt (self.fourmoluFor system) pkgs'.hlint ];
            } ''
            export LC_CTYPE=C.UTF-8
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            cd ${inputs.self}
            make format_check || (echo "    Please run 'make format'" ; exit 1)
            find -name '*.hs' -not -path './dist*/*' -not -path './haddock/*' | xargs hlint
            mkdir $out
          '';
      };

    # For developing _this repository_, having nixpkgs-fmt available is convenient.
    devShell = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let pkgs = import nixpkgs {
        inherit system;
      };
      in
      pkgs.mkShell {
        name = "shell";
        buildInputs = [ pkgs.nixpkgs-fmt ];
      }
    );
  };
}
