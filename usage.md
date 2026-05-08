# Usage

This project packages the Go greeter with Nix and provides both a local binary
and a Docker image.

## Prerequisites

- Nix with flakes enabled.
- Docker, only if you want to load and run the image locally.

## Build The Greeter

Build the default package:

```shell
nix build
```

This creates a `result` symlink pointing at the built package. The greeter
binary is available at:

```shell
./result/bin/greeter
```

To print the store path without creating a `result` symlink:

```shell
nix build --no-link --print-out-paths
```

## Run Locally

Run the service with Nix:

```shell
HELLO_TAG=test HOSTNAME=local nix run
```

The service listens on port `8080`. In another terminal, verify it responds:

```shell
curl http://localhost:8080/
```

You can append text to the greeting with the `textInjection` query parameter:

```shell
curl 'http://localhost:8080/?textInjection=welcome'
```

Missing or empty `textInjection` values leave the default greeting unchanged.
The response is served as `text/plain; charset=utf-8` with
`X-Content-Type-Options: nosniff`, so injected text is rendered as text rather
than interpreted as HTML.

`HELLO_TAG` is runtime configuration. Set it in the shell, container runtime,
Kubernetes deployment, or CI/CD environment that starts the service.

## Build The Docker Image

Build the Nix Docker image artifact:

```shell
nix build .#dockerImage
```

This creates a `result` symlink pointing at a Docker image tarball. Load it into
Docker:

```shell
docker load -i result
```

To build the image tarball without creating a `result` symlink:

```shell
nix build .#dockerImage --no-link --print-out-paths
```

Then load the printed path:

```shell
docker load -i /nix/store/...-greeter.tar.gz
```

## Run The Docker Image

Run the loaded image:

```shell
docker run --rm -p 8080:8080 -e HELLO_TAG=test greeter:latest
```

Verify it responds:

```shell
curl http://localhost:8080/
```

The same query parameter works when running the Docker image:

```shell
curl 'http://localhost:8080/?textInjection=welcome'
```

## Verify The Flake

Run all flake checks:

```shell
nix flake check
```

The checks build both the greeter binary and the Docker image.
