#!/bin/bash -e

CURDIR=$(pwd)
yarn install --cache-folder .yarn
ionic build

export IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend:$CI_COMMIT_TAG
echo "Building $IMAGE_TAG_FRONTEND"
/usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile"

echo "Compiling custom images"
TARGETDIR="${CI_PROJECT_DIR:-.}/customers/"
[[ -d "$TARGETDIR" ]] && find "$TARGETDIR" -name Dockerfile | while read -r file; do
    echo "Compiling a custom image for: $file";
    # Looking if there is a custom script
    DIRNAME=$(dirname "$file")
    IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend-$(basename "$DIRNAME"):$CI_COMMIT_TAG

    export IMAGE_TAG_FRONTEND
    export DIRNAME
    echo "Building $IMAGE_TAG_FRONTEND"
    /usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile.customer"
done
