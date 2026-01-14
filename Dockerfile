FROM ubuntu:24.04

# Ensure 'users' group (gid 100)
# and 'ubuntu' user (uid 1000) exist early.
# PITFALL: Those numbers should match what 'id' shows on host.
RUN groupadd -g 100 users || true

# Create ubuntu user only if it doesn't already exist in base image
RUN id -u ubuntu >/dev/null 2>&1 \
  || useradd -m -u 1000 -g users -s /bin/bash ubuntu

RUN mkdir -p /home/ubuntu/host && chown -R 1000:100 /home/ubuntu

# Force rebuilding from here.
RUN echo "Today is 2025 10 23"

RUN apt update  -y --fix-missing && \
    apt upgrade -y


###
### requirements for Rust and/or TypeDB
###

RUN apt install -y curl
RUN apt install -y gpg
RUN apt install -y pkg-config
RUN apt install -y ca-certificates
RUN apt install -y libssl-dev
RUN apt install -y apt-transport-https
RUN apt install -y software-properties-common
RUN apt install -y build-essential
RUN apt install -y default-jre


###
### configure Rust
###

RUN curl --proto '=https' --tlsv1.2 -sSf                     \
      https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    cp -r /root/.cargo /usr/local/cargo                   && \
    cp -r /root/.rustup /usr/local/rustup

# This `chown` is so slow that I have divided it in two.
RUN chown -R ubuntu:users /usr/local/cargo
RUN chown -R ubuntu:users /usr/local/rustup
RUN mkdir -p              /usr/local/cargo/git/db && \
    chown -R ubuntu:users /usr/local/cargo/git/db

# Set Rust environment variables globally
ENV PATH="/usr/local/cargo/bin:${PATH}"
ENV RUSTUP_HOME="/usr/local/rustup"
ENV CARGO_HOME="/usr/local/cargo"


###
### TypeDB
###

RUN apt install -y software-properties-common apt-transport-https gpg
RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 17507562824cfdcc
RUN gpg --export 17507562824cfdcc | tee /etc/apt/trusted.gpg.d/typedb.gpg > /dev/null
RUN echo "deb https://repo.typedb.com/public/public-release/deb/ubuntu trusty main" | tee /etc/apt/sources.list.d/typedb.list > /dev/null
RUN apt update -y
RUN apt install -y typedb
RUN chmod -R        777   /opt/typedb && \
    chown -R ubuntu:users /opt/typedb
# See also 'cargo watch' installed as USER below.


###
### Claude Code and Codex
###   Most of these are required by Claude Code; see
###     https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview
###

RUN apt install -y python3 python3-pip
RUN apt install -y python3-venv
RUN apt install -y pipx
RUN apt install -y git
RUN apt install -y nodejs
RUN apt install -y ripgrep
RUN apt install -y npm
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g @openai/codex


###
### More stuff I want
###

RUN apt install -y emacs
RUN apt install -y sqlite3 ripgrep
RUN apt install -y iproute2
RUN apt install -y pipewire-audio-client-libraries pipewire-bin


###
### Interface
###

# PITFALL: switches user
USER ubuntu
ENV PATH="/home/ubuntu/.local/bin:${PATH}"
RUN cargo install cargo-watch
RUN cargo install cargo-nextest
USER root
RUN mkdir /home/sound/
COPY copy-when-rebuilding/sound /home/sound/
USER ubuntu


###
### RUN
###

EXPOSE 1729
CMD ["/bin/bash"]
