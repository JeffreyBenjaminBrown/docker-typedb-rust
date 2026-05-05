{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  typedb  = pkgs.callPackage ./typedb.nix {};
  pkgConfigPath = pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
    pkgs.openssl
    pkgs.zlib
    pkgs.libgit2
    pkgs.libssh2
  ];

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
    users:x:100:
    ubuntu:x:1000:
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
  bashrcFile = pkgs.writeText "bashrc" ''
    case $- in
      *i*) ;;
      *) return ;;
    esac

    if command -v update-ai-clis >/dev/null 2>&1; then
      ai_cli_stamp=''${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli-updates/last-success
      ai_cli_lock=''${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli-updates/lock
      mkdir -p "$(dirname "$ai_cli_stamp")"

      if [ ! -e "$ai_cli_stamp" ] || find "$ai_cli_stamp" -mtime +0 >/dev/null 2>&1; then
        (
          if mkdir "$ai_cli_lock" 2>/dev/null; then
            trap 'rmdir "$ai_cli_lock"' EXIT
            if update-ai-clis >/tmp/update-ai-clis.log 2>&1; then
              touch "$ai_cli_stamp"
            fi
          fi
        ) >/dev/null 2>&1 &
      fi
    fi

    PS1='\w [\D{%F %T}]\n\$ '
  '';
  updateAiClis = pkgs.writeShellScriptBin "update-ai-clis" ''
    set -eu

    prefix="''${NPM_CONFIG_PREFIX:-$HOME/.local/npm-global}"
    mkdir -p "$prefix/bin" "$prefix/lib/node_modules"
    npm install -g @openai/codex@latest @anthropic-ai/claude-code@latest
  '';
  codexWrapper = pkgs.writeShellScriptBin "codex" ''
    set -eu

    prefix="''${NPM_CONFIG_PREFIX:-$HOME/.local/npm-global}"
    real="$prefix/bin/codex"
    if [ ! -x "$real" ]; then
      echo "Bootstrapping Codex from npm into $prefix" >&2
      update-ai-clis
    fi
    exec "$real" "$@"
  '';
  claudeWrapper = pkgs.writeShellScriptBin "claude" ''
    set -eu

    prefix="''${NPM_CONFIG_PREFIX:-$HOME/.local/npm-global}"
    real="$prefix/bin/claude"
    if [ ! -x "$real" ]; then
      echo "Bootstrapping Claude Code from npm into $prefix" >&2
      update-ai-clis
    fi
    exec "$real" "$@"
  '';

  # Embed the contents of ./copy-when-rebuilding/sound under /home/sound.
  soundFiles = pkgs.runCommand "sound-files" {} ''
    mkdir -p $out/home/sound
    cp ${./copy-when-rebuilding/sound}/* $out/home/sound/
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
    updateAiClis
    codexWrapper
    claudeWrapper

    # Local files
    soundFiles
  ]) ++ (with pkgs.dockerTools; [
    usrBinEnv binSh caCertificates
    # NOTE: not using fakeNss because we write our own passwd/group below.
  ]);

  extraCommands = ''
    mkdir -p etc home/ubuntu home/ubuntu/.cargo home/ubuntu/.rustup home/ubuntu/.local tmp root var/empty var/lib/typedb opt/typedb
    cp ${passwdFile}   etc/passwd
    cp ${groupFile}    etc/group
    cp ${nsswitchConf} etc/nsswitch.conf
    cp ${bashrcFile}   home/ubuntu/.bashrc
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
