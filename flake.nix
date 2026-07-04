{
  description = "Nix flake for the Lumide code editor (https://lumide.dev)";

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
      # Single source of truth for platforms. Add "aarch64-linux" here (and uncomment
      # its entry in pkgs/lumide/default.nix) once upstream publishes an arm64 asset.
      supportedSystems = [ "x86_64-linux" ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lumide = pkgs.callPackage ./pkgs/lumide { };
      in
      {
        packages = {
          default = lumide;
          lumide = lumide;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = lumide;
          name = "lumide";
        };

        formatter = pkgs.nixfmt;
      }
    )
    // {
      overlays.default = final: prev: {
        lumide = final.callPackage ./pkgs/lumide { };
      };
    };
}
