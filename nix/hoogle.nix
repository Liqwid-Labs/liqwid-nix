#
# Build a hoogle docker image from a haskell.nix project
#
{ pkgs
, lib
, project
, hoogle
  # inline-r is known to fail
, banList ? [ "inline-r" ]
, hoogleDirectory
, ...
}:
let
  hoogle-static = pkgs.stdenvNoCC.mkDerivation {
    name = "hoogle-static";
    src = pkgs.pkgsStatic.haskellPackages.hoogle;
    installPhase = ''
      mkdir $out
      cp -r bin $out/bin
    '';
  };
  hoogle-database =
    pkgs.runCommand "hoogle-generate"
      {
        buildInputs = (project.flake { }).devShell.nativeBuildInputs;
      }
      ''
        mkdir -p $out
        hoogle generate --local --database=$out/local.hoo
      '';
  fromPackage = b:
    if !(builtins.isNull b) && b.components ? library && b.components.library ? doc
    then b.components.library.doc
    else null;

  # We filter out any package that doesn't have documentation, collecting them all into a list.
  docsMap =
    builtins.filter (p: !(builtins.isNull p))
      (builtins.attrValues
        (builtins.mapAttrs (n: p: if !(builtins.elem n banList) then fromPackage p else null) project.hsPkgs));

  # Alpine is simple and lean!
  baseImage = pkgs.dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:1304f174557314a7ed9eddb4eab12fed12cb0cd9809e4c28f29af86979a3c870";
    sha256 = "sha256-uaJxeiRm94tWDBTe51/KwUBKR2vj9i4i3rhotsYPxtM=";
    finalImageTag = "3.16.2";
    finalImageName = "alpine";
  };

  inherit (pkgs.lib) optionalString;
in
pkgs.dockerTools.buildLayeredImage {
  name = "liqwid-nix-hoogle";
  tag = "latest";
  fromImage = baseImage;
  contents = [
    docsMap
    hoogle-static
  ];
  config = {
    Cmd = [
      "${pkgs.bash}/bin/bash"
      "-c"
      ''
        mkdir -p ./hoogle
        cp -r ${hoogle}/* ./hoogle
        ${optionalString (hoogleDirectory != null) "cp -r ${hoogleDirectory}/* ./hoogle"}
        hoogle server --port 8081 --home https://hoogle.nix.dance --local --host='*' --database ${hoogle-database}/local.hoo --datadir hoogle
      ''
    ];
    ExposedPorts = {
      "8081/tcp" = { };
    };
  };
}
