# Revision history for liqwid-nix

This format is based on [Keep A Changelog](https://keepachangelog.com/en/1.0.0).

## 2.2.0 - 2023-01-02

- Add `fourmolu.package` and `applyRefact.package` options.
- This change is breaking due to https://github.com/NixOS/nixpkgs/issues/112494

## 2.1.1 - 2022-12-26

- Off-chain module requires inputs being passed by project consuming liqwid-nix
  instead of being provided by liqwid-nix directly.
  
  This reduces inputs and as a result flake.lock size.
  
## 2.1.0 - 2022-12-21

- Add an off-chain module for CTL projects.

- Updated flake-parts, passing inputs now instead of self.

- On-chain exports packages now, which can be accessed the normal way.

- Templates no longer have bash prompt override.

## 2.0.1 -- 2022-12-12

- Vendored version of mkHackage instead of using now deprecated `haskell-nix-extra-hackage`.

- `hlint` and `haskell-language-server` provided using `tools` option of haskell.nix instead
  of manually.

## 2.0.0 -- 2022-11-28

- Rework Nix system into using flake-parts.

  Major differences:

  - Configuring uses modular system, which requires a few more nix files, 
    but it allows simultaneously having off-chain and on-chain in a single 
    repository.

  - Most flake inputs are managed inside of liqwid-nix instead of the projects
    using it. This means that versioning liqwid-nix is a bit more important.
    This is actually a big improvement, because previously having the inputs
    controlled by the user of the liqwid-nix library gave the illusion of
    freedom: Users can change versions at will and so they expect things to
    work together well, even when rarely this was the case. Now, a single
    liqwid-nix version will rule them all.

  - Run scripts are slightly different now. `nix run .#help` is useful for
    looking at them.

- Bumped to Fourmolu 0.9.0.0.

- Plutarch 1.3.0 is enforced for on-chain projects.

- GHC 9.2.4 is encouraged for on-chain projects.

## 1.1.0 -- 2022-10-24

- Bump fourmolu to 0.8.2.0.

  NOTE: nixpkgs-latest must be bumped to at least revision f53c279a60ee4c92a2140e65264f67ca91d42bac.

- Add frequently used scripts for easier development.

## 1.0.0 -- 2022-08-15

### Added

- First release
