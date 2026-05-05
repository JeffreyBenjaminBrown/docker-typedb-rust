{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  typedb  = pkgs.callPackage ./typedb.nix {};
  tidalGhc = pkgs.haskellPackages.ghcWithPackages (ps: [ ps.tidal ]);

  # fakeNss only provides root+nobody. We run the container with --user 1000:1000,
  # so we supply a proper /etc/passwd + /etc/group that includes that uid.
  passwdFile = pkgs.writeText "passwd" ''
    root:x:0:0:root:/root:${pkgs.bashInteractive}/bin/bash
    nobody:x:65534:65534:nobody:/var/empty:/bin/false
    ubuntu:x:1000:100:ubuntu:/home/ubuntu:${pkgs.bashInteractive}/bin/bash
  '';
  groupFile = pkgs.writeText "group" ''
    root:x:0:
    nobody:x:65534:
    users:x:100:ubuntu
    audio:x:63:ubuntu
  '';
  nsswitchConf = pkgs.writeText "nsswitch.conf" ''
    passwd:    files
    group:     files
    shadow:    files
    hosts:     files dns
    networks:  files
    protocols: files
    services:  files
  '';

  # Embed the contents of ./copy-when-rebuilding/sound under /home/sound.
  soundFiles = pkgs.runCommand "sound-files" {} ''
    mkdir -p $out/home/sound
    cp ${./copy-when-rebuilding/sound}/* $out/home/sound/
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "jeffreybenjaminbrown/hode";
  tag  = "latest";

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
    neo4j
    typedb

    # languages
    rustup
    python3
    nodejs_24
    tidalGhc cabal-install

    # editor
    emacs

    # Rust dev ergonomics (replace `cargo install cargo-watch/cargo-nextest`)
    cargo-watch cargo-nextest

    # Audio: SC+sc3-plugins from your host store; pipewire for client libs/tools.
    # Supercollider's runtime closure will pull in libjack transitively, and it
    # talks to your host PipeWire daemon via the bind-mounted socket.
    supercollider-with-sc3-plugins
    pipewire
    alsa-utils

    # AI CLIs. `claude-code` is unfree; you have allowUnfree in your host config.
    # `codex` package name in nixpkgs is uncertain — verify with
    #   `nix-env -qaP '.*codex.*'`
    # and uncomment a matching line below.
    claude-code
    # openai-codex     # <- common name; adjust if different in your channel

    # Local files
    soundFiles
  ]) ++ (with pkgs.dockerTools; [
    usrBinEnv binSh caCertificates
    # NOTE: not using fakeNss because we write our own passwd/group below.
  ]);

  extraCommands = ''
    mkdir -p etc home/ubuntu tmp root var/empty
    cp ${passwdFile}   etc/passwd
    cp ${groupFile}    etc/group
    cp ${nsswitchConf} etc/nsswitch.conf
    chmod 1777 tmp
  '';

  config = {
    Cmd         = [ "${pkgs.bashInteractive}/bin/bash" ];
    WorkingDir  = "/home/ubuntu";
    Env = [
      "PATH=/bin:/usr/bin"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "HOME=/home/ubuntu"
      "USER=ubuntu"
      "RUSTUP_HOME=/home/ubuntu/.rustup"
      "CARGO_HOME=/home/ubuntu/.cargo"
    ];
    ExposedPorts = {
      "1729/tcp" = {};   # TypeDB
      "7687/tcp" = {};   # Neo4j bolt
    };
  };
}
