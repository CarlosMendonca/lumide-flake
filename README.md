# lumide-flake

A Nix flake packaging the [Lumide](https://lumide.dev) code editor, a
desktop-first, GPU-accelerated editor built with Flutter, from its prebuilt
Linux release.

## Requirements

Lumide ships no license (all rights reserved), so Nix treats it as **unfree**.
Allow unfree packages when building or running:

```sh
export NIXPKGS_ALLOW_UNFREE=1   # and pass --impure below
```

or set `nixpkgs.config.allowUnfree = true;` (or add `lumide` to
`allowUnfreePredicate`) in your own configuration.

## Run

```sh
nix run --impure github:CarlosMendonca/lumide-flake
```

## Install into a profile

```sh
nix profile install --impure github:CarlosMendonca/lumide-flake#lumide
```

This installs the `lumide` binary plus a desktop entry
(`io.sofluffy.lumide.desktop`) and icon, so it shows up in your application
launcher.

## Use as an overlay

```nix
{
  inputs.lumide.url = "github:CarlosMendonca/lumide-flake";

  # in your nixpkgs config:
  nixpkgs.overlays = [ inputs.lumide.overlays.default ];
  # then: environment.systemPackages = [ pkgs.lumide ];
  #   or: home.packages = [ pkgs.lumide ];
}
```

## OpenGL / nixGL

Lumide renders with OpenGL. On **NixOS** this works out of the box via the
system graphics driver (`/run/opengl-driver`). On **other distributions**, a
`nix`-installed GUI app may not find a working `libGL`; if you see `libGL` or
GLX errors, run it under [nixGL](https://github.com/nix-community/nixGL):

```sh
nix run --impure github:nix-community/nixGL -- lumide
```

## Platform support

- **`x86_64-linux`**: supported (the only Linux asset upstream currently
  publishes).
- **`aarch64-linux`**: not yet; upstream publishes no arm64 Linux build. When
  it does, support is a one-line addition (see `supportedSystems` in `flake.nix`
  and the `sources` map in `pkgs/lumide/default.nix`).
- **macOS**: planned. Upstream ships a `.dmg`, which needs a separate
  derivation (not yet included).

## Updating

The pinned version and hash are bumped automatically by
`.github/workflows/update.yml` (weekly, via [`nix-update`](https://github.com/Mic92/nix-update)),
which commits the bump directly when a newer release builds. To bump manually:

```sh
nix run nixpkgs#nix-update -- --flake --version=stable lumide
```
