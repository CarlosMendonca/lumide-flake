{
  description = "Nix flake for the Lumide code editor (https://lumide.dev), version-selectable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Single source of truth for platforms. Add "aarch64-linux" here (and a
      # matching SYSTEMS entry in updater/update.sh) once upstream publishes an
      # arm64 Linux asset.
      supportedSystems = [ "x86_64-linux" ];

      lumideData = builtins.fromJSON (builtins.readFile ./data/lumide.json);

      mkPackages =
        pkgs:
        import ./lib/mk-packages.nix {
          inherit pkgs lumideData;
          lib = pkgs.lib;
        };
    in
    {
      # Fold every lumide_*/lumide package into a consumer's nixpkgs. Build from
      # `prev` (leaf packages that don't reference other lumide packages), and drop
      # the `default` alias so consumers don't get a stray `pkgs.default`.
      overlays.default = _final: prev: removeAttrs (mkPackages prev) [ "default" ];
    }
    // flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # `nix run .#update` regenerates data/lumide.json from the GitHub releases API.
        update = pkgs.writeShellApplication {
          name = "lumide-update";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
            pkgs.coreutils
          ];
          text = ''exec bash ${./updater/update.sh} "$@"'';
        };
      in
      {
        packages = mkPackages pkgs;

        apps.update = {
          type = "app";
          program = "${update}/bin/lumide-update";
          meta.description = "Regenerate data/lumide.json from the Lumide GitHub releases";
        };
        apps.default = self.apps.${system}.update;

        formatter = pkgs.nixfmt;
      }
    );
}
