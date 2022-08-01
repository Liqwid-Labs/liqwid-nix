# liqwid-nix

A simple library for writing nix flakes in Liqwid Labs projects. The aim of liqwid-nix is to reduce duplication of shared code, while providing a flexible escape for when real changes need to be applied.

### Example `flake.nix` using `liqwid-nix` for building [plutarch](https://github.com/Plutonomicon/plutarch-plutus) projects.

If you want to build a plutarch project using cabal and nix, here is a simple example `flake.nix` setup:

```nix
{
  description = "my project";

  inputs.nixpkgs.follows = "plutarch/nixpkgs";
  inputs.nixpkgs-latest.url = "github:NixOS/nixpkgs?rev=a0a69be4b5ee63f1b5e75887a406e9194012b492";
  inputs.nixpkgs-2111 = { url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin"; };

  # Plutarch and its friends
  inputs.plutarch.url =
    "github:Plutonomicon/plutarch-plutus?rev=67dc9cc1011044d37efc881e8f2ee491b7b8488a";
  inputs.plutarch.inputs.emanote.follows =
    "plutarch/haskell-nix/nixpkgs-unstable";
  inputs.plutarch.inputs.nixpkgs.follows =
    "plutarch/haskell-nix/nixpkgs-unstable";

  inputs.haskell-nix-extra-hackage.follows = "plutarch/haskell-nix-extra-hackage";
  inputs.haskell-nix.follows = "plutarch/haskell-nix";
  inputs.iohk-nix.follows = "plutarch/iohk-nix";
  inputs.haskell-language-server.follows = "plutarch/haskell-language-server";
  inputs.liqwid-nix.url = "github:Liqwid-Labs/liqwid-nix";

  outputs = inputs@{ liqwid-nix, ... }:
    (liqwid-nix.buildProject
      {
        inherit inputs;
        src = ./.;
      }
      [
        liqwid-nix.haskellProject
        liqwid-nix.plutarchProject
        (liqwid-nix.addChecks
          {
            liqwid-nix-test = "liqwid-nix-test:exe:liqwid-nix-test";
          })
        (liqwid-nix.enableFormatCheck [
          "-XQuasiQuotes"
          "-XTemplateHaskell"
          "-XTypeApplications"
          "-XImportQualifiedPost"
          "-XPatternSynonyms"
          "-XOverloadedRecordDot"
        ])		
      ]
    ).toFlake;

}
```

Some things to note:
- We have full responsibility over the inputs and their revision -- liqwid-nix is passed the inputs and tries to build using them, but it may fail.
- The first argument of `buildProject` _must_ have `src` and `inputs` passed to it. We are free to pass extra arguments, and those will be available from within an overlay through the `args` attribute of `self`.
- The second argument of `buildProject` has two overlays applied, `haskellProject` and `plutarchProject`. These are overlays which make this actually create a plutarch project. Both are required. You can also pass your own overlays.
- We extract `.toFlake` from the output of `buildProject` because the convention is that all overlays must preserve an eventual `toFlake` attribute that represents the resulting flake. 

## Which inputs do we need to provide?

For haskell projects, you need to provide:
- `nixpkgs-latest`, which should be a relatively up to date revision of nixpkgs. Example url: `github:NixOS/nixpkgs?rev=a0a69be4b5ee63f1b5e75887a406e9194012b492`.
- `haskell-nix-extra-hackage`, which allows us to create our own hackages.
- `haskell-nix`, which allows us to actually build cabal files. Example url: `github:input-output-hk/haskell.nix`.
- `nixpkgs`, which should follow `haskell-nix`: `inputs.nixpkgs.follows = "haskell-nix/nixpkgs-unstable";`
- `iohk-nix`. Example url: `github:input-output-hk/iohk-nix`.
- `haskell-language-server`. Example url: `github:haskell/haskell-language-server`.

See [the nixos wiki on Flakes](https://nixos.wiki/wiki/Flakes) for more information on how inputs work.

## Writing your own overlays

In the _ideally_ rare (but in practice quite common) event where you need to change something about the way the project is built, you can apply an _overlay_ on top of the other ones. 

```nix
# buildProject arguments
[
  liqwid-nix.haskellProject
  liqwid-nix.plutarchProject
  (self: super: {
      # your changes to the project's attributes here!
  })
]
```

This allows you to make an infinite amount of adjustments to how liqwid-nix works, though you will need to understand the actual underlying mechanisms for the way the project is built.

Let's say you want to add a new custom input to the hackage. We can do this using an overlay that looks like this:

```nix
(self: super: {
  hackageDeps = (super.hackageDeps or []) ++ [
    "${inputs.my-package}"
  ];
})
```

Now, if you apply this on top of `haskellProject` and `plutarchProject`, and you have an input called `my-package`, it will now be added to the custom hackage.

For this specific use case, there is already a helper function called `addDependencies`, which can be used like so:

```nix
(liqwid-nix.addDependencies [
 "${inputs.my-package}"
])
```
