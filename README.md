# lumide-flake

A Nix flake packaging the [Lumide](https://lumide.dev) code editor, a
desktop-first, GPU-accelerated editor built with Flutter, from its prebuilt
Linux releases. Every published release is exposed as its own package, so you
can pin an exact version or track the newest.

## Requirements

Lumide ships no license (all rights reserved), so Nix treats it as **unfree**.
Allow unfree packages when building or running:

```sh
export NIXPKGS_ALLOW_UNFREE=1   # and pass --impure below
```

or set `nixpkgs.config.allowUnfree = true;` (or add `lumide` to
`allowUnfreePredicate`) in your own configuration.

## Choosing a version

Each release is a selectable package attribute named `lumide_<major>_<minor>_<patch>`
(the version's `.` become `_`):

```
lumide_0_14_0   lumide_0_13_0   …   lumide_0_2_0
```

Convenience aliases always point at the newest release:

| attribute | meaning |
| --- | --- |
| `lumide` | latest release |
| `default` | latest release (so a plain `nix run` works) |

Versions `0.2.0` through `0.14.0` are available (`0.1.0` shipped no Linux build).

## Run

```sh
# Latest release
nix run --impure github:CarlosMendonca/lumide-flake

# A specific version
nix run --impure github:CarlosMendonca/lumide-flake#lumide_0_12_0
```

## Install into a profile

```sh
nix profile install --impure github:CarlosMendonca/lumide-flake#lumide
# or a pinned version:
nix profile install --impure github:CarlosMendonca/lumide-flake#lumide_0_9_0
```

This installs the `lumide` binary plus a desktop entry
(`io.sofluffy.lumide.desktop`) and icon, so it shows up in your application
launcher.

## Use as an overlay

Folds every `lumide` / `lumide_*` package onto your own `pkgs`:

```nix
{
  inputs.lumide.url = "github:CarlosMendonca/lumide-flake";

  # in your nixpkgs config:
  nixpkgs.overlays = [ inputs.lumide.overlays.default ];
  # then: environment.systemPackages = [ pkgs.lumide ];
  #   or a pinned version: home.packages = [ pkgs.lumide_0_12_0 ];
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
  it does, support is a two-line addition (add `"aarch64-linux"` to
  `supportedSystems` in `flake.nix` and an `aarch64-linux:arm64` entry to
  `SYSTEMS` in `updater/update.sh`, then rerun the updater).
- **macOS**: planned. Upstream ships a `.dmg`, which needs a separate
  derivation (not yet included).

## How it works

- `data/lumide.json` holds one entry per `(version, system)` with the release's
  download URL and `sha256`. `flake.nix` reads it and turns each entry into a
  package (`lib/mk-lumide.nix`); `lib/mk-packages.nix` assembles the full set
  shared by `packages.<system>` and `overlays.default`.
- The asset filename does not always match the release tag (older assets embed a
  `_1` build suffix), so the data file records each real download URL rather than
  constructing it.

## Updating the data

```sh
nix run .#update
```

`updater/update.sh` regenerates `data/lumide.json` from the GitHub releases API.
It reads each asset's published `sha256` digest, so no archive is downloaded.
`.github/workflows/update.yml` runs it weekly and pushes new versions to `main`
once the flake still evaluates and the latest release builds.
