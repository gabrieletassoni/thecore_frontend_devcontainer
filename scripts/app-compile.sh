#!/bin/bash -e

CURDIR=$(pwd)
yarn install --cache-folder .yarn

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/master:$CI_COMMIT_TAG
echo "Building $IMAGE_TAG_BACKEND"
/usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile"

echo "Compiling custom images"
TARGETDIR="${CI_PROJECT_DIR:-.}/customers/"
[[ -d "$TARGETDIR" ]] && find "$TARGETDIR" -name Dockerfile | while read -r file; do
    echo "Compiling a custom image for: $file";
    # Looking if thre is a custom script
    DIRNAME=$(dirname "$file")
    PRECOMPILESCRIPT="$DIRNAME/pre-compile.sh"
    [[ -f $PRECOMPILESCRIPT ]] && export `$PRECOMPILESCRIPT`

    yarn install --cache-folder .yarn

    export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/$(basename "$DIRNAME"):$CI_COMMIT_TAG
    echo "Building $IMAGE_TAG_BACKEND"
    /usr/bin/docker-build.sh "$file"
done