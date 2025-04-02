FROM ubuntu:24.10

RUN echo "2025 03 13"
RUN apt update  -y --fix-missing && \
    apt upgrade -y


###
### For the TypeDB server
###

RUN apt install -y \
  software-properties-common apt-transport-https gpg
RUN gpg --keyserver \
  hkp://keyserver.ubuntu.com:80 --recv-key 17507562824cfdcc
RUN gpg --export 17507562824cfdcc \
  | tee /etc/apt/trusted.gpg.d/typedb.gpg \
  > /dev/null
RUN echo "deb https://repo.typedb.com/public/public-release/deb/ubuntu trusty main" \
  | tee /etc/apt/sources.list.d/typedb.list \
  > /dev/null
RUN apt update  -y --fix-missing && \
    apt upgrade -y
RUN apt install -y default-jre
RUN apt install -y typedb


###
### The Rust client for TypeDB
###

RUN apt install -y curl

RUN curl --proto '=https' --tlsv1.2 -sSf                     \
      https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    cp -r /root/.cargo /usr/local/cargo                   && \
    cp -r /root/.rustup /usr/local/rustup

RUN chown -R ubuntu:users /usr/local/cargo \
                          /usr/local/rustup

# Set Rust environment variables globally
ENV PATH="/usr/local/cargo/bin:${PATH}"
ENV RUSTUP_HOME="/usr/local/rustup"
ENV CARGO_HOME="/usr/local/cargo"


###
### Stragglers. It would be more natural to install these earlier,
### but that would make building the container slower now.
###

RUN apt update  -y --fix-missing && \
    apt upgrade -y

RUN apt install -y build-essential
RUN apt install -y pkg-config
RUN apt install -y ca-certificates


###
### Interface
###

RUN chmod -R        777   /opt/typedb && \
    chown -R ubuntu:users /opt/typedb

# TODO: This could be merged with something earlier,
# when I have time for a longer docker build.
RUN mkdir -p              /usr/local/cargo/git/db && \
    chown -R ubuntu:users /usr/local/cargo/git/db

USER ubuntu

EXPOSE 1729
CMD ["/bin/bash"]
