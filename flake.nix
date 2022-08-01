{
  description = "Nix tools for building Liqwid projects";

  outputs = { self, nixpkgs }: rec {
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
    buildProject = args@{ inputs
      , supportedSystems ? inputs.nixpkgs-latest.lib.systems.flakeExposed
      , ghcVersion ? "ghc923", ... }:
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
        resolved =
          builtins.foldl' (super: overlay: super // overlay resolved super) base
          (baseOverlays ++ overlays);
      in resolved;

    # Haskell project overlay.
    # 
    # Use this in order to create haskell projects using cabal.
    # Keep in mind, a number of inputs will need to be provided, including:
    # - haskell-nix-extra-hackage
    # - iohk-nix
    # - haskell-nix
    # - nixpkgs
    # - haskell-language-server
    # - nixpkgs-latest, which is a *later* version of nixpkgs.
    haskellProject = self: super:
      let
        inherit (self)
          inputs nixpkgs nixpkgs-latest haskell-nix pkgsFor pkgsFor';
      in {
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
          inputs.haskell-nix-extra-hackage.mkHackagesFor system
          compiler-nix-name self.hackageDeps;

        haskellModules = super.haskellModules or [ ];

        applyDep = pkgs: o:
          let
            h = self.customHackages pkgs.system o.compiler-nix-name;
            o' = (super.applyDep or (p: o: o)) pkgs o;
          in o' // rec {
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
          in if (compiler-nix-name == "ghc${oldGhc}") then
            pkgs.haskell-language-server.override {
              supportedGhcVersions = [ oldGhc ];
            }
          else
            (self.hlsFor' compiler-nix-name
              pkgs).hsPkgs.haskell-language-server.components.exes.haskell-language-server;

        commandLineTools = system:
          let
            pkgs = pkgsFor system;
            pkgs' = pkgsFor' system;
            sup = super.commandLineTools or (system: [ ]);
          in (sup system) ++ [
            pkgs'.cabal-install
            pkgs'.hlint
            pkgs'.haskellPackages.cabal-fmt
            (self.fourmoluFor system)
            pkgs'.nixpkgs-fmt
            (self.hlsFor self.ghcVersion system)
            pkgs'.fd
            pkgs'.entr
            pkgs'.haskellPackages.apply-refact
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
          in pkgSet;

        projectFor = self.projectForGhc self.ghcVersion;

        formatCheckFor = system:
          let pkgs' = pkgsFor' system;
          in pkgs'.runCommand "format-check" {
            nativeBuildInputs = [
              pkgs'.haskellPackages.cabal-fmt
              pkgs'.nixpkgs-fmt
              (self.fourmoluFor system)
              pkgs'.hlint
            ];
          } ''
            export LC_CTYPE=C.UTF-8
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            cd ${inputs.self}
            make format_check || (echo "    Please run 'make format'" ; exit 1)
            find -name '*.hs' -not -path './dist*/*' -not -path './haddock/*' | xargs hlint
            mkdir $out
          '';

        specDefinition = super.specDefinition or { };

        toFlake = let inherit (self) perSystem projectFor;
        in (super.toFlake or { }) // rec {
          project = perSystem projectFor;
          flake = perSystem (system: (projectFor system).flake { });

          packages = perSystem (system: flake.${system}.packages // { });

          # Define what we want to test
          checks = perSystem (system:
            let
              checks = builtins.mapAttrs
                (name: value: self.toFlake.flake.${system}.packages.${value})
                self.specDefinition.checks or { };
              format = if self.specDefinition.format or false == true then {
                formatCheck = self.formatCheckFor system;
              } else
                { };
            in self.toFlake.flake.${system}.checks // checks // format);

          check = perSystem (system:
            (pkgsFor system).runCommand "combined-test" {
              checksss = builtins.attrValues self.toFlake.checks.${system};
            } ''
              echo $checksss
              touch $out
            '');
          devShell = perSystem (system: self.toFlake.flake.${system}.devShell);
        };
      };

    addCommandLineTools = addF: self: super: {
      commandLineTools = system:
        let
          pkgs = self.pkgsFor system;
          pkgs' = self.pkgsFor' system;
          sup = super.commandLineTools or (system: [ ]);
        in sup ++ (addF pkgs pkgs');
    };

    # Add input-based dependencies to hackage deps
    addDependencies = addedDependencies: self: super: {
      hackageDeps = (super.hackageDeps or [ ]) ++ addedDependencies;
    };

    # Define tests for Haskell project.
    addChecks = checks: self: super: {
      specDefinition = super.specDefinition or { } // checks;
    };

    # Plutarch project overlay.
    plutarchProject = self: super:
      let
        inherit (self) inputs pkgsFor pkgsFor' fourmoluFor;
        inherit (inputs) nixpkgs nixpkgs-latest haskell-nix plutarch;
      in {
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
          in o' // rec {
            modules = self.haskellModules ++ h.modules ++ (o.modules or [ ]);
            extra-hackages = h.extra-hackages ++ (o.extra-hackages or [ ]);
            extra-hackage-tarballs = h.extra-hackage-tarballs
              // (o.extra-hackage-tarballs or { });
            cabalProjectLocal = o'.cabalProjectLocal or "" + (''
              allow-newer:
                cardano-binary:base
                , cardano-crypto-class:base
                , cardano-prelude:base
                , canonical-json:bytestring
                , plutus-core:ral
                , plutus-core:some
                , int-cast:base
                , inline-r:singletons
              constraints:
                OneTuple >= 0.3.1
                , Only >= 0.1
                , QuickCheck >= 2.14.2
                , StateVar >= 1.2.2
                , Stream >= 0.4.7.2
                , adjunctions >= 4.4
                , aeson >= 2.0.3.0
                , algebraic-graphs >= 0.6
                , ansi-terminal >= 0.11.1
                , ansi-wl-pprint >= 0.6.9
                , assoc >= 1.0.2
                , async >= 2.2.4
                , attoparsec >= 0.14.4
                , barbies >= 2.0.3.1
                , base-compat >= 0.12.1
                , base-compat-batteries >= 0.12.1
                , base-orphans >= 0.8.6
                , base16-bytestring >= 1.0.2.0
                , basement >= 0.0.12
                , bifunctors >= 5.5.11
                , bimap >= 0.4.0
                , bin >= 0.1.2
                , boring >= 0.2
                , boxes >= 0.1.5
                , cabal-doctest >= 1.0.9
                , call-stack >= 0.4.0
                , canonical-json >= 0.6.0.0
                , cardano-binary >= 1.5.0
                , cardano-crypto >= 1.1.0
                , cardano-crypto-class >= 2.0.0
                , cardano-prelude >= 0.1.0.0
                , case-insensitive >= 1.2.1.0
                , cassava >= 0.5.2.0
                , cborg >= 0.2.6.0
                , clock >= 0.8.2
                , colour >= 2.3.6
                , comonad >= 5.0.8
                , composition-prelude >= 3.0.0.2
                , concurrent-output >= 1.10.14
                , constraints >= 0.13.2
                , constraints-extras >= 0.3.2.1
                , contravariant >= 1.5.5
                , cryptonite >= 0.29
                , data-default >= 0.7.1.1
                , data-default-class >= 0.1.2.0
                , data-default-instances-containers >= 0.0.1
                , data-default-instances-dlist >= 0.0.1
                , data-default-instances-old-locale >= 0.0.1
                , data-fix >= 0.3.2
                , dec >= 0.0.4
                , dependent-map >= 0.4.0.0
                , dependent-sum >= 0.7.1.0
                , dependent-sum-template >= 0.1.1.1
                , deriving-aeson >= 0.2.8
                , deriving-compat >= 0.6
                , dictionary-sharing >= 0.1.0.0
                , distributive >= 0.6.2.1
                , dlist >= 1.0
                , dom-lt >= 0.2.3
                , double-conversion >= 2.0.2.0
                , erf >= 2.0.0.0
                , exceptions >= 0.10.4
                , extra >= 1.7.10
                , fin >= 0.2.1
                , flat >= 0.4.5
                , foldl >= 1.4.12
                , formatting >= 7.1.3
                , foundation >= 0.0.26.1
                , free >= 5.1.7
                , half >= 0.3.1
                , hashable >= 1.4.0.2
                , haskell-lexer >= 1.1
                , hedgehog >= 1.0.5
                , indexed-traversable >= 0.1.2
                , indexed-traversable-instances >= 0.1.1
                , integer-logarithms >= 1.0.3.1
                , invariant >= 0.5.5
                , kan-extensions >= 5.2.3
                , lazy-search >= 0.1.2.1
                , lazysmallcheck >= 0.6
                , lens >= 5.1
                , lifted-async >= 0.10.2.2
                , lifted-base >= 0.2.3.12
                , list-t >= 1.0.5.1
                , logict >= 0.7.0.3
                , megaparsec >= 9.2.0
                , memory >= 0.16.0
                , microlens >= 0.4.12.0
                , mmorph >= 1.2.0
                , monad-control >= 1.0.3.1
                , mono-traversable >= 1.0.15.3
                , monoidal-containers >= 0.6.2.0
                , mtl-compat >= 0.2.2
                , newtype >= 0.2.2.0
                , newtype-generics >= 0.6.1
                , nothunks >= 0.1.3
                , old-locale >= 1.0.0.7
                , old-time >= 1.1.0.3
                , optparse-applicative >= 0.16.1.0
                , parallel >= 3.2.2.0
                , parser-combinators >= 1.3.0
                , plutus-core >= 0.1.0.0
                , plutus-ledger-api >= 0.1.0.0
                , plutus-tx >= 0.1.0.0
                , pretty-show >= 1.10
                , prettyprinter >= 1.7.1
                , prettyprinter-configurable >= 0.1.0.0
                , primitive >= 0.7.3.0
                , profunctors >= 5.6.2
                , protolude >= 0.3.0
                , quickcheck-instances >= 0.3.27
                , ral >= 0.2.1
                , random >= 1.2.1
                , rank2classes >= 1.4.4
                , recursion-schemes >= 5.2.2.2
                , reflection >= 2.1.6
                , resourcet >= 1.2.4.3
                , safe >= 0.3.19
                , safe-exceptions >= 0.1.7.2
                , scientific >= 0.3.7.0
                , semialign >= 1.2.0.1
                , semigroupoids >= 5.3.7
                , semigroups >= 0.20
                , serialise >= 0.2.4.0
                , size-based >= 0.1.2.0
                , some >= 1.0.3
                , split >= 0.2.3.4
                , splitmix >= 0.1.0.4
                , stm >= 2.5.0.0
                , strict >= 0.4.0.1
                , syb >= 0.7.2.1
                , tagged >= 0.8.6.1
                , tasty >= 1.4.2.1
                , tasty-golden >= 2.3.5
                , tasty-hedgehog >= 1.1.0.0
                , tasty-hunit >= 0.10.0.3
                , temporary >= 1.3
                , terminal-size >= 0.3.2.1
                , testing-type-modifiers >= 0.1.0.1
                , text-short >= 0.1.5
                , th-abstraction >= 0.4.3.0
                , th-compat >= 0.1.3
                , th-expand-syns >= 0.4.9.0
                , th-extras >= 0.0.0.6
                , th-lift >= 0.8.2
                , th-lift-instances >= 0.1.19
                , th-orphans >= 0.13.12
                , th-reify-many >= 0.1.10
                , th-utilities >= 0.2.4.3
                , these >= 1.1.1.1
                , time-compat >= 1.9.6.1
                , transformers-base >= 0.4.6
                , transformers-compat >= 0.7.1
                , type-equality >= 1
                , typed-process >= 0.2.8.0
                , unbounded-delays >= 0.1.1.1
                , universe-base >= 1.1.3
                , unliftio-core >= 0.2.0.1
                , unordered-containers >= 0.2.16.0
                , uuid-types >= 1.0.5
                , vector >= 0.12.3.1
                , vector-algorithms >= 0.8.0.4
                , void >= 0.7.3
                , wcwidth >= 0.0.2
                , witherable >= 0.4.2
                , wl-pprint-annotated >= 0.1.0.1
                , word-array >= 0.1.0.0
                , secp256k1-haskell >= 0.6
                , inline-r >= 0.10.5
            '');
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
    devShell = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let pkgs = import nixpkgs { inherit system; };
      in pkgs.mkShell {
        name = "shell";
        buildInputs = [ pkgs.nixpkgs-fmt ];
      });
  };
}
