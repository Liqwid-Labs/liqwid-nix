{ config, lib, flake-parts-lib, ... }:
{
  config = {
    flake = {
      templates.default = {
        path = ../templates/onchain;
        description = "A Plutarch project";
      };
      templates.offchain = {
        path = ../templates/offchain;
        description = "A CTL project";
      };
    };
  };
}

