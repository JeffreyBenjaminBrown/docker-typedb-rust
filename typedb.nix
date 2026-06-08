{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, zlib, openssl }:

stdenv.mkDerivation rec {
  pname = "typedb";
  version = "3.11.5";

  src = fetchurl {
    url = "https://repo.typedb.com/public/public-release/raw/names/typedb-all-linux-x86_64/versions/${version}/typedb-all-linux-x86_64-${version}.tar.gz";
    hash = "sha256-fwyTzcEfgXd1klLPaMrP8ncrEzhfdJdbjiaXgrFB/Bo=";
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
