# Revision history for liqwid-nix

This format is based on [Keep A Changelog](https://keepachangelog.com/en/1.0.0).

## 2.9.2 - 2023-06-14

- Add liqwid-nix module documentation generation. Both onchain and offchain have their modules included.
  Pending implementation for automating this workstream.

## 2.9.1 - 2023-05-26

- Hercules CI option is moved from `flake` to top level, by using hercules-ci-effects module.
  Downstream users of liqwid-nix can as a result now configure options without conflicting with defaults.

## 2.9.0

- Modified the onchain module to take any modules given 
  on `extraHackageDeps` over that given on upstream hackage.

## 2.8.0

- Added `compileStrict` option in offchain module.

## 2.7.2 - 2023-03-22

- Enable Hercules CI support.

## 2.7.1 - 2023-03-17

- Remove uses of `ifEnable`.
- When plutip or purescript tests are null, liqwid-nix no longer throws an error,
  but ignores them silently.

## 2.7.0 - 2023-03-16

- Requires CTL v5 now.
- Remove vendored `bundlePursProject`, since CTL supports this now.
- Allow building on darwin by excluding chromium build.

## 2.6.1 - 2023-03-08

- Provide `pre-commit-hooks` flake for formatter and linker hooks. 
  Check [cachix/pre-commit-hooks.nix](https://github.com/cachix/pre-commit-hooks.nix) 
  to see how to configure.

## 2.6.0 - 2023-02-27

- Make `packageJson` and `packageLock` required options in offchain module. CTL docs say that "It is *highly* recommended to pass" in order to prevent unncecessary rebuilds.

## 2.5.0 - 2023-02-22

- Exposable hoogle docker image.

## 2.4.0 - 2023-02-17

- Default `exposeConfig` to `false` in offchain module

## 2.3.1 - 2023-02-09

- Added option (`spagoOverride`) to offchain module. This allows one to use package from flake instead of pulling from git when building derviation. This resolves problem from CI where CI machine fails to pull from private repository via ssh.

- Fix a bug in the offchain module caused by 2.3.0 which required specifying `pkgs`.

## 2.3.0 - 2023-01-25

- Added `shell.shellHook`, `pkgs`, and `runtime.exposeConfig` options in offchain module

- Fix inclusion of checks when no related project exists.

## 2.2.2 - 2023-01-16

- Fixed off-chain checks.

- Off-chain `spago bundle-module` output inclusion workaround.

## 2.2.1 - 2023-01-09

- Minor fixes to off-chain module.

- Dropped the Plutonomicon cache.

## 2.2.0 - 2023-01-02

- Add `fourmolu.package`, `applyRefact.package`, `hlint.package`,
  `cabalFmt.package`, and `hasktags.package` options.
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
