{
  description = "Nix tools for building Liqwid projects";

  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.nixpkgs-2205.url = "github:NixOS/nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs-2205, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      imports = [ ./nix/templates.nix ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          pkgs2205 = import nixpkgs-2205 { inherit system; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "liqwid-nix dev shell";
            buildInputs = [
              pkgs2205.nixpkgs-fmt
            ];
          };
          formatter = pkgs2205.nixpkgs-fmt;
        };
      flake = { };
    };
}
