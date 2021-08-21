{ pkgs ? import <nixpkgs> { } }: (import <arc> { inherit pkgs; }).shells.rust.stable.overrideAttrs ( old: {
  nativeBuildInputs = old.nativeBuildInputs or [] ++ [
    pkgs.pkg-config
  ];
  buildInputs = old.buildInputs ++ [
    pkgs.openssl
    pkgs.xorg.libX11
    pkgs.xorg.libXrandr
  ];
})
