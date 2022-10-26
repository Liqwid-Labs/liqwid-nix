{
  description = "Nix tools for building Liqwid projects";

  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.nixpkgs-2205.url = "github:NixOS/nixpkgs/nixos-22.05";

  outputs = { self, flake-parts, ... }:
    let
      modules = [ ./nix/onchain.nix ./nix/defaultDevShell.nix ];
    in
    flake-parts.lib.mkFlake { inherit self; } {
      imports = modules;
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: { };
      flake = {
        modules = {
          imports = modules;
        };
      };
    };
}
