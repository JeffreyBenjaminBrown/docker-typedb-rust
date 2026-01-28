exit # This is not a script, just snippets.

CONTAINER_NAME=rust-typedb
docker run --name $CONTAINER_NAME -it -d                   \
  -v /home/jeff/hodal/docker-typedb-rust:/home/ubuntu/host \
  -v /run/user/1000/pipewire-0:/run/user/1000/pipewire-0   \
  -e PIPEWIRE_RUNTIME_DIR=/run/user/1000                   \
  --group-add $(getent group audio | cut -d: -f3)          \
  --network host                                           \
  --platform linux/amd64                                   \
  --user 1000:1000                                         \
  --dns 8.8.8.8                                            \
  --dns 1.1.1.1                                            \
  jeffreybbrown/hode:latest # PITFALL: New? Latest?
  # '--network host' plugs each port into the host port of the same number -- in particular, so that 1730 (Rust-Emacs) in the container corresponds to the same port on the host.
  # At least one of those --dns options was helpful for getting Claude to work over my phone's mobile hotspot.
docker exec -it $CONTAINER_NAME bash

docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME

STARTING_AT=$(date)
echo $(date)
docker build -t jeffreybbrown/hode:new .
echo $(date)

DOCKER_IMAGE_SUFFIX="sound-again"
docker tag jeffreybbrown/hode:new jeffreybbrown/hode:latest
docker tag jeffreybbrown/hode:new jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker rmi jeffreybbrown/hode:new

docker push jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker push jeffreybbrown/hode:latest
