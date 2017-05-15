# ACS Runtime Docker image

This little repository helps in creating a runtime docker image for the [acs-engine](https://github.com/Azure/acs-engine) command line tool, which is used for creating Azure Resource Manager configuration files and parameter files for creating various container orchestration system deployments.

The acs-engine repository itself contains excellent scripting for setting up a development environment, but it does not provide an easy way of leveraging `acs-engine` in an automated way. This is where this repository comes in: It enables you to create a minimal docker image which is able to run `acs-engine`, which is suitable to use e.g. from build pipelines.

## What does this do?

The `build-runtime.sh` scripts does the following things:

* Clone `acs-engine` into the current path, with a configurable source; if the path is present, do a `git pull`
* Invoke `./scripts/devenv.sh` and automatically call `make build` to build the `acs-engine` executable
* Build a minimal docker image which can be used to just run `acs-engine`

## Usage

### Building the runtime image

Set the following environment variables:

Name | Default | Description
-----|---------|--------------
`ACS_ENGINE_REPO` | `https://github.com/Azure/acs-engine` | The source repository for the `acs-engine` repository. If you do not specify this, the `HEAD` of the original repository will be used. Override if you have your own fork, or if you want to specify exactly when you want to pull in changes from upstream into your own fork of `acs-engine`
`ACS_RUNTIME_IMAGE` | -- | The name of the runtime image you want to create, **without** the tag; e.g. `registry.yourcompany.io/azure/acs-engine`
`DOCKER_TAGS` | `latest` | (OPTIONAL) Space-delimited list of docker tags to create and (optionally) push; example: `export DOCKER_TAGS="$(date +%Y%m%d%H%M%S) latest"`
`DOCKER_REGISTRY_USER` | -- | (OPTIONAL) Docker registry username; specify if you want to automatically push the image to a Docker registry
`DOCKER_REGISTRY_PASSWORD` | -- | (OPTIONAL) If `DOCKER_REGISTRY_PASSWORD` is specified, you also need to specify this env var
`DOCKER_REGISTRY` | Docker Hub | (OPTIONAL) If you want to push your image to a custom Docker registry, specify the FQDN of the registry here, e.g. `someregistry.azurecr.io`

Then call the script

```
$ ./build-runtime.sh
```

If you have specified `DOCKER_REGISTRY_USER` and `DOCKER_REGISTRY_PASSWORD`, the script will log in to either Docker Hub, or the registry you (optionally) specified in `DOCKER_REGISTRY`, and subsequently push the image with the tags you (optionally) specified in `DOCKER_TAGS`.

Note that you may specify multiple tags, space-delimited, in `DOCKER_TAGS`. If you choose not to specify a list of tags, the docker tag `:latest` will be created.

Now you're set and done to use the runtime image in your build pipelines.

### Using the runtime image

Inside your build pipeline, you can invoke the runtime image like this. It's assumed that the configuration JSON file (the API model) is called `model.json`, and that you want your output in the directory `output`:

```
docker run --rm -v `pwd`:/model <image name> generate --api-model /model/model.json --output-directory /model/output
```

Note that we mount the current directory (`pwd`) into the runtime container as `/model`, which is why we need to specify the source of the `--api-model` as `/model/model.json`, and likewise with the output directory.

In case you are running on Linux, it may happen that the generated files belong to `root`, and need to be `chown`:ed, but that's left as an exercise ;-)

# LICENSE

[Apache-2.0](LICENSE)