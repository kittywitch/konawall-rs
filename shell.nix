{
  pkgs,
  rust,
  system,
}:
rust.devShells.${system}.channels.stable.overrideAttrs (old: {
  nativeBuildInputs =
    old.nativeBuildInputs
    or []
    ++ [
      pkgs.pkg-config
    ];
  buildInputs =
    old.buildInputs
    ++ [
      pkgs.openssl
      pkgs.xorg.libX11
      pkgs.xorg.libXrandr
    ];
})
