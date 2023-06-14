# liqwid-nix

A simple library for writing nix flakes in Liqwid Labs projects. The aim of liqwid-nix is to reduce duplication of shared code, while providing a flexible escape for when real changes need to be applied.

See the [module docs](https://liqwid-labs.github.io/liqwid-nix/reference/modules.html)!

## Features

- On-chain project support using Plutarch
- Off-chain project support using CTL
- Overridable configuration using flake-parts

### Using direnv.

Since flakes built using `liqwid-nix` provide various command-line tools that are useful for development of the projects they live in, it is useful to have them available when entering a directory. [nix-direnv](https://github.com/nix-community/nix-direnv) helps with this. Setup instructions are available in the repo README. It is not standard practice to _commit_ the `.envrc`, so you are required to create these yourself for every repository you clone. As described in the repo, it boils down to the same thing every time, `echo "use flake" > .envrc && direnv allow`.

In the case that there already is a `flake.nix` file, you must remove it or the template will refuse to be applied.

### Run scripts

`liqwid-nix` uses `nix run` to expose various useful scripts. Try `nix run .#help` to list out the scripts available for a given project. (Not applicable in `liqwid-nix` itself)
