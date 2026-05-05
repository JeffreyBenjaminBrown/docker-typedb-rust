exit # This is not a script, just snippets.

### Run the container ###
### ================= ###
CONTAINER_NAME=rust-typedb
IMAGE_NAME=jeffreybbrown/hode:latest
docker run --name $CONTAINER_NAME -it -d                       \
  -v /home/jeff/hodal/docker-typedb-rust:/home/ubuntu/host     \
  -v /nix/store:/nix/store:ro                                  \
  -v /run/user/1000/pipewire-0:/run/user/1000/pipewire-0       \
  -e PIPEWIRE_RUNTIME_DIR=/run/user/1000                       \
  --group-add $(getent group audio | cut -d: -f3)              \
  --ulimit rtprio=95                                           \
  --ulimit memlock=-1                                          \
  --network host                                               \
  --platform linux/amd64                                       \
  --user 1000:1000                                             \
  --dns 8.8.8.8                                                \
  --dns 1.1.1.1                                                \
  $IMAGE_NAME
  # PITFALL: --network host plugs container ports into host ports.
  # PITFALL: /nix/store bind-mount means the image's store references
  #   resolve against the host store at runtime. Keep it :ro.
  # PITFALL: --ulimit rtprio/memlock are needed inside Docker; musnix
  #   settings on the host don't cross the container boundary.

### Build the image (Nix, fast) ###
### =========================== ###
# Produces ./result which is a .tar.gz Docker image archive.
# First-time run will fail with the real TypeDB tarball hash — paste it
# into typedb.nix (replacing lib.fakeHash) and rerun.
nix-build docker.nix
echo "WARNING: Hold onto the result file. Because the container bind-mounts the host / nix/store, aggressive GC on the host can also break an already-loaded image at runtime if the required store paths are no longer rooted. Keeping result around, or adding a GC root for the built image closure, makes that safer."
docker load < result
# The image loads as `jeffreybbrown/hode:latest`, thanks to the
# pkgs.dockerTools.buildLayeredImage.name field in docker.nix

### Build the image (conventional, slow) ###
### ==================================== ###
STARTING_AT=$(date)
echo $(date)
docker build -t jeffreybbrown/hode:new .
echo $(date)

### tag/push ###
### ======== ###
DOCKER_IMAGE_SUFFIX="newer-typedb"
docker tag jeffreybbrown/hode:latest jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker push jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker push jeffreybbrown/hode:latest

### start/stop ###
### ========== ###
docker exec -it $CONTAINER_NAME bash

docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
