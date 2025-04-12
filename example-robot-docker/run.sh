#!/bin/bash

# example usage:
# ./run.sh ros:noetic
# For non-interactive mode: ./run.sh --detached [ros:noetic]

set -e

INTERACTIVE=true
if [[ "$1" == "--detached" ]]; then
  INTERACTIVE=false
  shift
fi

BUILDARGS=""
TAGNAME=cavalla_001
if [[ $# > 0 ]]; then
  TAGNAME+=_${1/:/-}
  BUILDARGS+="--build-arg BASE_IMAGE=$1"
fi;

# generate a random four-digit number
NUMBER=$(tr -dc 0-9 < /dev/urandom | fold -w 4 | head -n 1)

. .env
BUILDARGS+=" --build-arg USERID=$USERID"
BUILDARGS+=" --build-arg TOKEN=$TOKEN"

docker build $BUILDARGS -t $TAGNAME .

DIR=/tmp/transitive_$NUMBER
mkdir -p $DIR
echo "TR_LABELS=docker" > $DIR/.env_user

if [ "$INTERACTIVE" = true ]; then
  # Interactive mode with terminal
  echo "Starting Docker container in interactive mode"
  docker run -it --rm \
  --privileged \
  --hostname robot_${TAGNAME}_${NUMBER} \
  -v $DIR:/root/.transitive \
  -v /run/udev:/run/udev \
  --device=/dev/video0 \
  -v /sys:/sys \
  -v /dev:/dev \
  -e UDEV=1 \
  --name robot \
  $TAGNAME $2
else
  # Non-interactive mode for services
  echo "Starting Docker container in detached mode"
  docker run -d --rm \
  --privileged \
  --hostname robot_${TAGNAME}_${NUMBER} \
  -v $DIR:/root/.transitive \
  -v /run/udev:/run/udev \
  --device=/dev/video0 \
  -v /sys:/sys \
  -v /dev:/dev \
  -e UDEV=1 \
  --name robot \
  $TAGNAME $2
  
  echo "Docker container started in background. Container name: robot"
fi