#!/bin/bash -e

# Saving original state
rm -rf /tmp/src.orig
cp --verbose -rf src /tmp/src.orig

# Actual build of the solution
yarn install --cache-folder .yarn
rm -rf dist
ionic build --prod --release

export IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend:$CI_COMMIT_TAG
echo "Building $IMAGE_TAG_FRONTEND"
/usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile"

echo "Compiling custom images"
TARGETDIR="${CI_PROJECT_DIR:-.}/customers/"
[[ -d "$TARGETDIR" ]] && find "$TARGETDIR" -name docker.env | while read -r file; do
    echo "Compiling a custom image for: $file";
    # Looking if there is a custom script
    DIRNAME=$(dirname "$file")
    # Redo the original src
    rm -rf src
    cp --verbose -rf /tmp/src.orig src
    
    # Replace src custom files into original position
    cp --verbose -rf ${DIRNAME}/src/* src/

    # Actual build of the solution
    yarn install --cache-folder .yarn
    rm -rf dist
    ionic build --prod --release

    IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend-$(basename "$DIRNAME"):$CI_COMMIT_TAG

    export IMAGE_TAG_FRONTEND
    echo "Building $IMAGE_TAG_FRONTEND"
    /usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile"
done
