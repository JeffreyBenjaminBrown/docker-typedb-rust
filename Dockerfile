FROM ubuntu:24.10

RUN echo "2025 04 29" # Forces rebuilding from here.
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



###
### Claude Code
###   see https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview
###

RUN apt install -y python3 python3-pip
RUN apt install -y python3-venv
RUN apt install -y git
RUN apt install -y nodejs
RUN apt install -y ripgrep
RUN apt install -y npm
RUN npm install -g @anthropic-ai/claude-code


###
### Interface
###

RUN chmod -R        777   /opt/typedb && \
    chown -R ubuntu:users /opt/typedb

# TODO: This could be merged with something earlier,
# when I have time for a longer docker build.
RUN mkdir -p              /usr/local/cargo/git/db && \
    chown -R ubuntu:users /usr/local/cargo/git/db

RUN apt install -y emacs

# 'aider' is an open source model-agnostic AI CLI agent.
# PITFALL: switches user twice
RUN apt install -y pipx # TODO: Group with other Python installsE
USER ubuntu
ENV PATH="/home/ubuntu/.local/bin:${PATH}"
RUN pipx install aider-install # for global installs
RUN aider-install
USER root


###
### TODO : Add data science
###

# See survey-1

###
### RUN
###

RUN mkdir /home/ubuntu/host/
USER ubuntu

EXPOSE 1729
CMD ["/bin/bash"]
