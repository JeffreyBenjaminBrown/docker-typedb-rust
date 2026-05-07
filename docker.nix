{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  typedb  = pkgs.callPackage ./typedb.nix {};
  pkgConfigPath = pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
    pkgs.openssl
    pkgs.zlib
    pkgs.libgit2
    pkgs.libssh2
  ];

  localBin = pkgs.runCommand "local-bin" {} ''
    mkdir -p $out/bin
    cp ${./copy-when-rebuilding/bin}/* $out/bin/
    chmod +x $out/bin/*
  '';

  # Embed the contents of ./copy-when-rebuilding/sound under /home/sound,
  # and build the default WAV samples at image-build time.
  soundFiles = pkgs.runCommand "sound-files" {} ''
    mkdir -p $out/home/sound
    cp ${./copy-when-rebuilding/sound}/* $out/home/sound/
    chmod +x $out/home/sound/*.sh
    PATH=${pkgs.python3}/bin:${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash \
      $out/home/sound/generate-soothing-beep.sh \
      $out/home/sound/beep.wav
    PATH=${pkgs.python3}/bin:${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash \
      $out/home/sound/generate-glorious-beep.sh \
      $out/home/sound/glorious-beep.wav
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "jeffreybbrown/hode";
  tag  = "untested";

  contents = (with pkgs; [
    # shell + core unix
    bashInteractive coreutils gnused gnugrep findutils gawk which diffutils
    less procps psmisc iproute2

    # network / TLS / gpg
    curl wget openssl gnupg

    # version control & search
    git ripgrep

    # build tools (for `cargo build`, native deps, etc.)
    gcc gnumake pkg-config cmake

    # databases
    sqlite
    # languages
    cargo
    python3
    pipx
    rustc
    nodejs_24

    # editor
    emacs
    emacsPackages.magit

    # Rust dev ergonomics (replace `cargo install cargo-watch/cargo-nextest`)
    cargo-watch cargo-nextest

    pipewire
    alsa-utils
    alsa-lib
    dbus
    glib
    libsndfile
    meson
    ninja
    portaudio
    systemd

    # AI CLI runtimes. The CLI packages themselves are installed into a
    # writable prefix at runtime so they can be upgraded independently of nixpkgs.
    localBin

    # Local files
    soundFiles
  ]) ++ (with pkgs.dockerTools; [
    usrBinEnv binSh caCertificates
    # NOTE: not using fakeNss because we write our own passwd/group below.
  ]);

  extraCommands = ''
    mkdir -p etc home/ubuntu home/ubuntu/.cargo home/ubuntu/.rustup home/ubuntu/.local tmp root var/empty var/lib/typedb opt/typedb
    cp ${./copy-when-rebuilding/etc/passwd}        etc/passwd
    cp ${./copy-when-rebuilding/etc/group}         etc/group
    cp ${./copy-when-rebuilding/etc/nsswitch.conf} etc/nsswitch.conf
    cp ${./copy-when-rebuilding/home/ubuntu/.bashrc} home/ubuntu/.bashrc
    chmod 0777 home/ubuntu home/ubuntu/.cargo home/ubuntu/.rustup home/ubuntu/.local
    chmod 0644 home/ubuntu/.bashrc

    # TypeDB needs a writable install tree at runtime. Leaving it only in
    # /nix/store makes `typedb server` fail because it writes relative to
    # TYPEDB_HOME/server/data.
    cp -r ${typedb}/opt/typedb/. opt/typedb/
    chmod -R u+w opt/typedb
    rm -rf opt/typedb/server/data opt/typedb/core
    mkdir -p opt/typedb/server opt/typedb/core/server var/lib/typedb/data
    ln -s /var/lib/typedb/data opt/typedb/server/data
    # Compatibility for scripts/docs that still reference the old apt layout.
    ln -s /var/lib/typedb/data opt/typedb/core/server/data
    ln -s /opt/typedb/typedb bin/typedb
    chmod -R 0777 opt/typedb var/lib/typedb

    chmod 1777 tmp
  '';

  config = {
    Cmd         = [ "${pkgs.bashInteractive}/bin/bash" ];
    WorkingDir  = "/home/ubuntu";
    Env = [
      "PATH=/home/ubuntu/.local/npm-global/bin:/bin:/usr/bin"
      "PKG_CONFIG_PATH=${pkgConfigPath}"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "HOME=/home/ubuntu"
      "USER=ubuntu"
      "NPM_CONFIG_PREFIX=/home/ubuntu/.local/npm-global"
      "RUSTUP_HOME=/home/ubuntu/.rustup"
      "CARGO_HOME=/home/ubuntu/.cargo"
    ];
    ExposedPorts = {
      "1729/tcp" = {};   # TypeDB
    };
  };
}
