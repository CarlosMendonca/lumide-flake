# Builds the full attrset of Lumide packages for `pkgs`' own system: one
# `lumide_<version>` per release, plus a `lumide` alias for the newest and a
# `default`. Shared by `packages.<system>` and `overlays.default` so the two can
# never drift apart.
{
  pkgs,
  lib,
  lumideData,
}:

let
  sanitize = import ./sanitize.nix;
  system = pkgs.stdenv.hostPlatform.system;

  entries = builtins.filter (e: e.system == system) lumideData;

  mkLumide = entry: import ./mk-lumide.nix { inherit pkgs lib entry; };

  # `lumide_<sanitized version>` for every release available on this system.
  named = lib.listToAttrs (
    map (e: {
      name = "lumide_${sanitize e.version}";
      value = mkLumide e;
    }) entries
  );

  # Highest version available on this system (null if none).
  latest =
    if entries == [ ] then
      null
    else
      lib.foldl' (
        acc: e: if builtins.compareVersions e.version acc.version > 0 then e else acc
      ) (builtins.head entries) entries;
in
named
# `lumide` -> newest release; `default` so a plain `nix run`/`nix build` works.
// lib.optionalAttrs (latest != null) {
  lumide = mkLumide latest;
  default = mkLumide latest;
}
