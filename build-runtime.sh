#!/bin/bash

set -e

trap traperror ERR

function traperror() {
   echo "ERROR: Something went wrong."
   if [ -f ./docker_tag.tmp ]; then
       echo "INFO: Remving temporary image."
       if ! docker rmi $(cat ./docker_tag.tmp); then
           echo "ERROR: Could not delete image."
       fi
   fi
   exit 1
}

if [ -z "${ACS_RUNTIME_IMAGE}" ]; then
  echo "ERROR: Target image name must be specified in env var ACS_RUNTIME_IMAGE prior"
  echo "starting this script."
  echo ""
  echo "Example:"
  echo "  ACS_RUNTIME_IMAGE=repo.yourcompany.io/azure/acs-engine $0"
  echo "  Specify tags to push in env var DOCKER_TAGS as space delimited list, e.g."
  echo "  DOCKER_TAGS=\"$(date +%Y%m%d%H%M%S) latest\""
  exit 1
fi

if [[ ${ACS_RUNTIME_IMAGE} == *":"* ]]; then
  echo "ERROR: The env var ACS_RUNTIME_IMAGE contains a ':'; specify the tag in the env var"
  echo "  DOCKER_TAGS instead. Leave DOCKER_TAGS empty to build :latest."
fi

if [ -z "${DOCKER_TAGS}" ]; then
  export DOCKER_TAGS="latest"
fi

if [ -z "${ACS_ENGINE_REPO}" ]; then
  export ACS_ENGINE_REPO=https://github.com/Azure/acs-engine
  echo "WARNING: Env var ACS_ENGINE_REPO is not set, assuming ${ACS_ENGINE_REPO}"
fi

if [ -d "./acs-engine" ]; then
  pushd acs-engine
  git pull
  popd
else
  git clone ${ACS_ENGINE_REPO}
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

randomId=$(od -vN "16" -An -tx1 /dev/urandom | tr -d " \n")

pushd docker
docker build -t ${randomId} .
for tag in ${DOCKER_TAGS}; do
  echo "INFO: Tagging as ${ACS_RUNTIME_IMAGE}:${tag}."
  docker tag ${randomId} ${ACS_RUNTIME_IMAGE}:${tag}
done
popd

if [ -z "${DOCKER_REGISTRY_USER}" ] || [ -z "${DOCKER_REGISTRY_PASSWORD}" ]; then
  echo "INFO: Not pushing image, env vars DOCKER_REGISTRY_USER or DOCKER_REGISTRY_PASSWORD not set."
else
  echo "INFO: Logging in to registry ${DOCKER_REGISTRY}..."
  if [ -z "${DOCKER_REGISTRY}" ]; then
    echo "INFO: Env var DOCKER_REGISTRY not set, assuming docker hub."
    docker login -u ${DOCKER_REGISTRY_USER} -p ${DOCKER_REGISTRY_PASSWORD}
  else
    docker login -u ${DOCKER_REGISTRY_USER} -p ${DOCKER_REGISTRY_PASSWORD} ${DOCKER_REGISTRY}
  fi

  for tag in ${DOCKER_TAGS}; do
    echo "INFO: Pushing image ${ACS_RUNTIME_IMAGE}."
    docker push ${ACS_RUNTIME_IMAGE}:${tag}
  done
fi

echo "INFO: Untagging random image name ${randomId}"
docker rmi ${randomId}

echo "INFO: Successfully finished."
