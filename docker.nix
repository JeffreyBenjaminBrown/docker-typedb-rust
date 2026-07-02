{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  typedb  = pkgs.callPackage ./typedb.nix {};
  emacsWithMagit =
    (pkgs.emacsPackagesFor pkgs.emacs).emacsWithPackages (epkgs: [
      epkgs.magit
    ]);
  pkgConfigPath = pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
    pkgs.alsa-lib
    pkgs.dbus
    pkgs.glib
    pkgs.libsndfile
    pkgs.openssl
    pkgs.pipewire
    pkgs.portaudio
    pkgs.libjack2
    pkgs.systemd
    pkgs.zlib
    pkgs.libgit2
    pkgs.libssh2
  ];
  guiLibraryPath = pkgs.lib.makeLibraryPath (with pkgs; [
    libx11
    libxcursor
    libxrandr
  ]);

  aiCliLibraryPath = pkgs.lib.makeLibraryPath (with pkgs; [
    # Shared libraries the npm-installed AI CLIs (claude, codex) need at runtime.
    # They are prebuilt FHS binaries, so they resolve libc, libstdc++, libgcc_s,
    # etc. by plain soname rather than through a Nix RPATH. All of these come from
    # the same nixpkgs as everything else in the image, so adding them to
    # LD_LIBRARY_PATH does not risk version skew with the Nix-built tools.
    glibc
    stdenv.cc.cc.lib
    zlib
    openssl
  ]);

  # Merged ALSA plugin dir that includes PipeWire's pcm/ctl plugins (which live
  # in the pipewire output, not alsa-lib's) alongside the standard converters.
  # ALSA_PLUGIN_DIR (in config.Env) points here, and /etc/asound.conf sets the
  # default PCM/CTL to `type pipewire`, so raw-ALSA apps route through PipeWire
  # instead of grabbing the card. See copy-when-rebuilding/etc/asound.conf.
  alsaPluginDir = pkgs.symlinkJoin {
    name = "alsa-plugins-with-pipewire";
    paths = [ pkgs.alsa-plugins pkgs.pipewire ];
  };

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
      $out/home/sound/generate-harsh-beep.sh
    PATH=${pkgs.python3}/bin:${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash \
      $out/home/sound/generate-soothing-beep.sh
    PATH=${pkgs.python3}/bin:${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash \
      $out/home/sound/generate-glorious-beep.sh
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
    netcat-gnu    # `nc` — to poke TCP ports (is TypeDB on 1729 / skg on 1730 up?)

    # version control & search
    git ripgrep

    # everyday CLI tools (these were missing from the image)
    jq            # query/transform JSON — the Emacs<->Rust API speaks JSON
    perl          # regex/text munging of org-mode files
    tree          # visualize directory structure
    fd            # fast, ergonomic file finder
    file          # identify file types
    bat           # syntax-highlighted, line-numbered file viewing
    htop          # interactive process / CPU monitor (e.g. spot TypeDB load)
    lsof          # which process holds a port / open file (1729, 1730, locks)
    tmux          # run/observe the servers in split panes
    gnupatch      # `patch` — apply diffs
    gnutar gzip   # tar + gzip were both absent; needed for archives & backups
    unzip         # extract .zip archives

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

    # editors
    # Use emacsWithPackages so Magit is on the default load-path of the
    # `emacs` executable. Including `emacsPackages.magit` separately adds
    # the store path to the image but does not make `(require 'magit)' work.
    emacsWithMagit
    (pkgs.neovim.override {
      # Neovim for the (planned) vim client -- the neovim analog of
      # emacsWithMagit -- wrapped with its third-party plugins baked onto its
      # packpath:
      #   - orgmode (nvim-orgmode) renders/folds the org-mode buffers the skg
      #     server sends. Its tree-sitter parser (org, v2.0.4) ships inside the
      #     tree-sitter-orgmode luarock at lib/lua/5.1/parser/org.so -- on Lua's
      #     cpath but NOT on neovim's runtimepath, so treesitter can't find it.
      #     The runCommand plugin below re-exposes that exact .so as parser/org.so
      #     on the packpath. (The standalone vimPlugins org grammars are v1.3.1,
      #     too old for this orgmode; nvim-treesitter has no `org` grammar at all.)
      #   - neogit (a magit clone) + its required plenary-nvim dep, plus
      #     diffview-nvim for diffs/merges: an in-editor git porcelain.
      # Only the editor and these plugins are baked in; the skg client's own Lua
      # lives in the mounted project tree and is loaded at runtime, exactly as
      # the elisp client is. (The .override expression is parenthesized because a
      # bare `pkgs.neovim.override { ... }` in a list parses as two elements.)
      configure = {
        packages.skg.start = [
          pkgs.vimPlugins.orgmode
          # The matching org tree-sitter parser (see comment above), lifted out
          # of the tree-sitter-orgmode luarock and onto the packpath as
          # parser/org.so so neovim's treesitter can load it.
          (pkgs.runCommandLocal "nvim-org-treesitter-parser" {} ''
            mkdir -p $out/parser
            cp ${pkgs.luajitPackages.tree-sitter-orgmode}/lib/lua/5.1/parser/org.so $out/parser/org.so
          '')
          pkgs.vimPlugins.neogit
          pkgs.vimPlugins.plenary-nvim  # neogit's required dependency
          pkgs.vimPlugins.diffview-nvim # optional, recommended with neogit
        ]; }; })

    # Rust dev ergonomics (replace `cargo install cargo-watch/cargo-nextest`)
    cargo-watch cargo-nextest clippy

    pipewire
    pipewire.jack
    alsa-utils
    alsa-lib
    alsa-lib.dev
    dbus
    dbus.dev
    glib
    glib.dev
    libsndfile
    libsndfile.dev
    meson
    ninja
    portaudio
    pipewire.dev
    systemd
    systemd.dev

    # minifb loads these with dlopen at runtime when opening X11 windows.
    libx11
    libxcursor
    libxrandr

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

    # The npm-installed claude/codex are prebuilt dynamic binaries whose
    # hardcoded ELF interpreter is the FHS path /lib64/ld-linux-x86-64.so.2.
    # A pure-Nix image has no such file, so execve() fails with ENOENT, which
    # the shell reports as "cannot execute: required file not found".
    # Provide the loader at the path these binaries bake in.
    mkdir -p lib64
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    cp ${./copy-when-rebuilding/etc/passwd}        etc/passwd
    cp ${./copy-when-rebuilding/etc/group}         etc/group
    cp ${./copy-when-rebuilding/etc/nsswitch.conf} etc/nsswitch.conf
    cp ${./copy-when-rebuilding/etc/asound.conf}   etc/asound.conf
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
      "LD_LIBRARY_PATH=${guiLibraryPath}:${aiCliLibraryPath}"
      # Where ALSA finds the pipewire pcm/ctl plugins referenced by
      # /etc/asound.conf, so the default device routes through PipeWire.
      "ALSA_PLUGIN_DIR=${alsaPluginDir}/lib/alsa-lib"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "HOME=/home/ubuntu"
      "USER=ubuntu"
      "NPM_CONFIG_PREFIX=/home/ubuntu/.local/npm-global"
      "RUSTUP_HOME=/home/ubuntu/.rustup"
      "CARGO_HOME=/home/ubuntu/.cargo"
      # Claude Code keeps ALL its state (history, sessions, credentials,
      # config) plus our shared user-level config (hooks/settings) under
      # CLAUDE_CONFIG_DIR. Pointing it inside the project bind-mount
      # (/home/ubuntu/host) makes that state persist across container rebuilds
      # with no separate .claude mount. The dir is a git checkout of
      # github.com/JeffreyBenjaminBrown/my-dot-claude (see ~/.bashrc, which
      # clones it on first interactive shell if absent).
      "CLAUDE_CONFIG_DIR=/home/ubuntu/host/my-dot-claude"
      # Where the PipeWire socket is bind-mounted, so the Claude stop-hook beep
      # can reach the server.
      "PIPEWIRE_RUNTIME_DIR=/run/user/1000"
    ];
    ExposedPorts = {
      "1729/tcp" = {};   # TypeDB
    };
  };
}
