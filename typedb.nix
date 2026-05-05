{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, zlib, openssl }:

stdenv.mkDerivation rec {
  pname = "typedb";
  version = "3.8.3";

  src = fetchurl {
    url = "https://repo.typedb.com/public/public-release/raw/names/typedb-all-linux-x86_64/versions/${version}/typedb-all-linux-x86_64-${version}.tar.gz";
    # On first build this will fail with the real hash in the error message.
    # Paste it in here and rebuild.
    hash = "sha256-gwtak+xErp8aI9SwtA+NrQ3NZ+mLR7ccdvB+8ojqYI8=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib zlib openssl ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt/typedb
    cp -r ./typedb-all-linux-x86_64-${version}/. $out/opt/typedb/ \
      2>/dev/null || cp -r ./. $out/opt/typedb/
    mkdir -p $out/bin
    ln -s $out/opt/typedb/typedb $out/bin/typedb
    runHook postInstall
  '';

  meta = with lib; {
    description = "TypeDB Community Edition (pre-built Linux x86_64)";
    homepage = "https://typedb.com";
    license = licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}
