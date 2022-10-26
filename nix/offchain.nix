# TODO: off CTL project configuration module.
{ self, config, lib, flake-parts-lib, ... }:

{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption ({ config, self', inputs', pkgs, system, ... }: { });
  };
  config = {
    perSystem = { config, self', inputs', pkgs, lib, ... }:
      { };
  };
}
