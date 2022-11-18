#!/bin/bash -e
echo "Testing docker installation."
docker version

cd "${CI_PROJECT_DIR}"

echo "Building Image $IMAGE_TAG_FRONTEND"
echo "Using $1 for build and files from $DIRNAME"
docker build -f "$1" --no-cache --pull -t "${IMAGE_TAG_FRONTEND}" .

echo "Login at $CI_REGISTRY"
docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

echo "Pushing Image $IMAGE_TAG_FRONTEND"
docker image push "${IMAGE_TAG_FRONTEND}"
