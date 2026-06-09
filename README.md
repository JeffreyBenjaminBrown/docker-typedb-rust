This Docker image contains Rust, TypeDB and Claude Code.
It is built with Nix (`nix-build docker.nix` then `docker load < result`);
there is no Dockerfile. See `commands.sh` for the full build/run recipe.

See [PITFALLS.org](PITFALLS.org) for operational pitfalls of the Nix
build and some maintenance notes.

# How safe is Claude Code in this Docker container?

Even if Claude were evil, it would not be able to do much damage from here. It only has access to the files mounted to the Docker container. While git is installed in this image, unless Claude acquires your credentials, it cannot push to your remote repo.
