{ liqwid-nix, system, pkgs, lib, ... }:
rec {
  mkPackageSpec = src:
    with lib;
    let
      cabalFiles = concatLists (mapAttrsToList
        (name: type: if type == "regular" && hasSuffix ".cabal" name then [ name ] else [ ])
        (builtins.readDir src));

      cabalPath =
        if length cabalFiles == 1
        then src + "/${builtins.head cabalFiles}"
        else builtins.abort "Could not find unique file with .cabal suffix in source: ${src}";
      cabalFile = builtins.readFile cabalPath;
      parse = field:
        let
          lines = filter (s: if builtins.match "^${field} *:.*$" (toLower s) != null then true else false) (splitString "\n" cabalFile);
          line =
            if lines != [ ]
            then head lines
            else builtins.abort "Could not find line with prefix ''${field}:' in ${cabalPath}";
        in
        replaceStrings [ " " ] [ "" ] (head (tail (splitString ":" line)));
      pname = parse "name";
      version = parse "version";
    in
    { inherit src pname version; };

  mkPackageTarball = { pname, version, src }:
    pkgs.runCommand "${pname}-${version}.tar.gz" { } ''
      tar --sort=name --owner=Hackage:0 --group=Hackage:0 --mtime='UTC 2009-01-01' -czvf $out ${src}
    '';

  mkHackageDir = { pname, version, src }@spec:
    pkgs.runCommand "${pname}-${version}-hackage"
      { } ''
      set -e
      mkdir -p $out/${pname}/${version}
      md5=11111111111111111111111111111111
      sha256=1111111111111111111111111111111111111111111111111111111111111111
      length=1
      cat <<EOF > $out/"${pname}"/"${version}"/package.json
      {
        "signatures" : [],
        "signed" : {
            "_type" : "Targets",
            "expires" : null,
            "targets" : {
              "<repo>/package/${pname}-${version}.tar.gz" : {
                  "hashes" : {
                    "md5" : "$md5",
                    "sha256" : "$sha256"
                  },
                  "length" : $length
              }
            },
            "version" : 0
        }
      }
      EOF
      cp ${src}/*.cabal $out/"${pname}"/"${version}"/
    '';

  mkHackageTarballFromDirs = hackageDirs:
    pkgs.runCommand "01-index.tar.gz" { } ''
      mkdir hackage
      ${builtins.concatStringsSep "" (map (dir: ''
        echo ${dir}
        ln -s ${dir}/* hackage/
      '') hackageDirs)}
      cd hackage
      tar --sort=name --owner=root:0 --group=root:0 --mtime='UTC 2009-01-01' -hczvf $out */*/*
    '';

  mkHackageTarball = pkg-specs:
    mkHackageTarballFromDirs (map mkHackageDir pkg-specs);

  mkHackageNix = compiler-nix-name: hackageTarball:
    pkgs.runCommand "hackage-nix" { } ''
      set -e
      export LC_CTYPE=C.UTF-8
      export LC_ALL=C.UTF-8
      export LANG=C.UTF-8
      cp ${hackageTarball} 01-index.tar.gz
      ${pkgs.gzip}/bin/gunzip 01-index.tar.gz
      ${pkgs.haskell-nix.nix-tools.${compiler-nix-name}}/bin/hackage-to-nix $out 01-index.tar "https://mkHackageNix/"
    '';

  copySrc = src: builtins.path {
    path = src;
    name = "copied-src-${builtins.baseNameOf (builtins.unsafeDiscardStringContext src)}";
  };

  mkModule = extraHackagePackages: {
    # Prevent nix-build from trying to download the packages
    packages = lib.listToAttrs (map
      (spec: {
        name = spec.pname;
        value = { src = lib.mkOverride 99 (copySrc spec.src); };
      })
      extraHackagePackages);
  };

  mkHackageFromSpec = compiler-nix-name: extraHackagePackages: rec {
    extra-hackage-tarball = mkHackageTarball extraHackagePackages;
    extra-hackage = mkHackageNix compiler-nix-name extra-hackage-tarball;
    module = mkModule extraHackagePackages;
  };

  mkHackage = compiler-nix-name: srcs:
    let
      # from mlabs-tooling.nix.
      hackages = [ (mkHackageFromSpec compiler-nix-name (map mkPackageSpec srcs)) ];
      ifd-parallel =
        pkgs.runCommandNoCC "ifd-parallel"
          { myInputs = builtins.foldl' (b: a: b ++ [ a.extra-hackage a.extra-hackage-tarball ]) [ ] hackages; }
          "echo $myInputs > $out";
      ifdseq = x: builtins.seq (builtins.readFile ifd-parallel.outPath) x;
    in
    {
      modules = ifdseq (builtins.map (x: x.module) hackages);
      extra-hackage-tarballs = ifdseq (
        lib.listToAttrs (lib.imap0
          (i: x: {
            name = "_" + builtins.toString i;
            value = x.extra-hackage-tarball;
          })
          hackages));
      extra-hackages = ifdseq (builtins.map (x: import x.extra-hackage) hackages);
    };
}
