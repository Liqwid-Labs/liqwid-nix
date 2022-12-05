{ config, lib, flake-parts-lib, ... }:
{
  config = {
    flake = {
      templates.default = {
        path = ../templates/onchain;
        description = "A Plutarch project";
      };
    };
  };
}

