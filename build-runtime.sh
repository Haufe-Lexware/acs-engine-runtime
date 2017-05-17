#!/bin/bash
set -e

cleanup() {
    test -n "${builder}" &&\
        echo "INFO: remove build container ${builder}" &&\
        docker rm -f "${builder}"
    test -n "${randomId}" &&\
        echo "INFO: Untagging random image name ${randomId}" &&\
        docker rmi "${randomId}"
}

trap cleanup 0

error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    if [[ -n "$message" ]] ; then
        echo "ERROR on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
    else
        echo "ERROR on or near line ${parent_lineno}; exiting with status ${code}"
    fi
    cleanup
    exit "${code}"
}

trap "error ${LINENO}" ERR

if [ -f "./env.sh" ]; then
  echo "INFO: Found env.sh in current directory, sourcing into script."
  source ./env.sh
fi

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

for tag in ${DOCKER_TAGS}; do
  echo "INFO: Preparing to push tag ${tag}"
done

if [ -z "${ACS_ENGINE_REPO}" ]; then
  export ACS_ENGINE_REPO=https://github.com/Azure/acs-engine
  echo "WARNING: Env var ACS_ENGINE_REPO is not set, assuming ${ACS_ENGINE_REPO}"
fi

build() {
    docker build -t acs-engine acs-engine
    builder=$(docker run -i -t -d acs-engine bash)
    echo "INFO: copy source code to build container"
    docker cp acs-engine ${builder}:/gopath/src/github.com/Azure/
    echo "INFO: build acs-engine"
    docker exec $builder make build
    echo "INFO: getting resulting artifact"
    docker cp ${builder}:/gopath/src/github.com/Azure/acs-engine/acs-engine docker
}

if [ -d "./acs-engine" ]; then
  pushd acs-engine
  git pull
  popd
else
  git clone ${ACS_ENGINE_REPO}
fi

echo "INFO: building builder image"
build -t acs-engine acs-engine

echo "INFO: Building acs-engine within builder image"
build
if [ ! -f "docker/acs-engine" ]; then
  echo "ERROR: Artifact docker/acs-engine was not built correctly. Exiting."
  exit 1
fi

randomId=$(od -vN "16" -An -tx1 /dev/urandom | tr -d " \n")

docker build -t ${randomId} docker
for tag in ${DOCKER_TAGS}; do
  echo "INFO: Tagging as ${ACS_RUNTIME_IMAGE}:${tag}."
  docker tag ${randomId} ${ACS_RUNTIME_IMAGE}:${tag}
done

if [ -n "${DOCKER_REGISTRY_USER}" ] && [ -n "${DOCKER_REGISTRY_PASSWORD}" ]; then
  echo "INFO: Logging in to registry ${DOCKER_REGISTRY}..."
  if [ -z "${DOCKER_REGISTRY}" ]; then
    echo "INFO: Env var DOCKER_REGISTRY not set, assuming docker hub."
    docker login -u ${DOCKER_REGISTRY_USER} -p ${DOCKER_REGISTRY_PASSWORD}
  else
    docker login -u ${DOCKER_REGISTRY_USER} -p ${DOCKER_REGISTRY_PASSWORD} ${DOCKER_REGISTRY}
  fi

  for tag in ${DOCKER_TAGS}; do
    echo "INFO: Pushing image ${ACS_RUNTIME_IMAGE}:${tag}"
    docker push ${ACS_RUNTIME_IMAGE}:${tag}
  done
else
  echo "INFO: Not pushing image, env vars DOCKER_REGISTRY_USER or DOCKER_REGISTRY_PASSWORD not set."
fi


echo "INFO: Successfully finished."
