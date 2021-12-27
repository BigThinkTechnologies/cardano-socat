#!/bin/bash

if docker build -t bigthink/cardano:socat-v1.0.0 . ; then
  docker push bigthink/cardano:socat-v1.0.0
else
  echo "error building and/or pushing docker image"
fi
