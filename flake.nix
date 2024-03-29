{
  description = "konawall-rs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust.url = "github:arcnmx/nixexprs-rust";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    rust,
  }:
    (flake-utils.lib.eachDefaultSystem
      (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          konawall = pkgs.callPackage ./package.nix {};
        in {
          packages = {
            inherit konawall;
            default = konawall;
          };
          devShells.default = import ./shell.nix {inherit system rust pkgs;};
        }
      ))
    // {
      hmModules.konawall = import ./home-manager.nix;
      darwinModules.konawall = import ./nix-darwin.nix;
      overlays.default = final: prev: let
        inherit (final.stdenv.hostPlatform) system;
      in {
        konawall = self.packages.${system}.konawall;
      };
    };
}
