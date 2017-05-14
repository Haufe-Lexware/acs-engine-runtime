#!/bin/bash

set -e

if [ -z "$ACS_RUNTIME_IMAGE" ]; then
  echo "ERROR: Target image name must be specified in env var ACS_RUNTIME_IMAGE prior"
  echo "starting this script."
  echo ""
  echo "Example:"
  echo "  ACS_RUNTIME_IMAGE=repo.yourcompany.io/azure/acs-engine:latest $0"
  exit 1
fi

if [ -z "$ACS_ENGINE_REPO" ]; then
  export ACS_ENGINE_REPO=https://github.com/Azure/acs-engine
  echo "WARNING: Env var ACS_ENGINE_REPO is not set, assuming $ACS_ENGINE_REPO"
fi

if [ -d "./acs-engine" ]; then
  pushd acs-engine
  git pull
  popd
else
  git clone $ACS_ENGINE_REPO
fi

pushd acs-engine

# script behaves differently on Linux and macOS...
if [ "Darwin" = $(uname) ]; then 
  script -q /dev/null ./scripts/devenv.sh << EOF
make build
exit
EOF
else
  script -qfc "./scripts/devenv.sh" /dev/null << EOF
make build
exit
EOF
fi

popd

cp acs-engine/acs-engine docker

pushd docker
docker build -t $ACS_RUNTIME_IMAGE .
popd
