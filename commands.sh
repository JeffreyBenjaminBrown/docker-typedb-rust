exit # This is not a script, just snippets.

CONTAINER_NAME=rust-typedb
docker run --name $CONTAINER_NAME -it -d         \
  -v /home/jeff/hodal/skg-copy:/home/ubuntu/host \
  -p 1731:1731                                   \
  --platform linux/amd64                         \
  --user 1000:1000                               \
  jeffreybbrown/hode:new # PITFALL: New? Latest?
docker exec -it $CONTAINER_NAME bash

docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME

STARTING_AT=$(date)
echo $(date)
docker build -t jeffreybbrown/hode:new .
echo $(date)

DOCKER_IMAGE_SUFFIX="2025-09-01.+aider"
docker tag jeffreybbrown/hode:new jeffreybbrown/hode:latest
docker tag jeffreybbrown/hode:new jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker rmi jeffreybbrown/hode:new

docker push jeffreybbrown/hode:$DOCKER_IMAGE_SUFFIX
docker push jeffreybbrown/hode:latest
