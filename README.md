# liqwid-nix

A simple library for writing nix flakes in Liqwid Labs projects. The aim of liqwid-nix is to reduce duplication of shared code, while providing a flexible escape for when real changes need to be applied.

### Using direnv.

Since flakes built using `liqwid-nix` provide various command-line tools that are useful for development of the projects they live in, it is useful to have them available when entering a directory. [nix-direnv](https://github.com/nix-community/nix-direnv) helps with this. Setup instructions are available in the repo README. It is not standard practice to _commit_ the `.envrc`, so you are required to create these yourself for every repository you clone. As described in the repo, it boils down to the same thing every time, `echo "use flake" > .envrc && direnv allow`.

### Using `liqwid-nix`.

This repository exposes nix templates that you can use to bootstrap your project. View the `templates` directory.

Use the following command to initialize a project using liqwid-nix:
```sh
nix flake init -t github:Liqwid-Labs/liqwid-nix/liqwid-nix-2.0
```

### Run scripts

`liqwid-nix` uses `nix run` to expose various useful scripts. Try `nix run .#help` to list out the scripts available for a given project. (Not applicable in `liqwid-nix` itself)
