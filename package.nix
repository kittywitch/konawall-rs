{
  fetchFromGitHub,
  rustPlatform,
  lib,
  pkg-config,
  openssl,
  libX11,
  libXrandr,
  stdenv,
  System ? apple_sdk.frameworks.System,
  Security ? apple_sdk.frameworks.Security,
  apple_sdk ? darwin.apple_sdk,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "konawall";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [pkg-config];
  buildInputs =
    [
      openssl
    ]
    ++ lib.optionals stdenv.isLinux [
      libX11
      libXrandr
    ]
    ++ lib.optionals stdenv.isDarwin [
      System
      Security
    ];

  env.NIX_LDFLAGS = lib.optionalString stdenv.isDarwin "-framework System";

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
  };

  cargoSha256 = "sha256-80TIGzVUnl5VvLbM4ZGwF02ZA2u3xdUNPTAGkWqun0E=";
}
