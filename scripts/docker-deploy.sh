#!/bin/bash -e

echo "COMMIT TAG: ${CI_COMMIT_TAG}"
VERSION=${CI_COMMIT_TAG}

# Used to not have conflicting installations
UUID=$(cat /proc/sys/kernel/random/uuid)
RELATIVE_DIR="/installers/$UUID"
TARGET_DIR="/tmp$RELATIVE_DIR"

echo "Target Dir: $TARGET_DIR"

# Setup SSH trust 
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n\tControlMaster auto\n\tControlPath ~/.ssh/socket-%C\n\tControlPersist 1\n\n" > ~/.ssh/config
chmod 600 ~/.ssh/config
echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

SEMVER=${VERSION%%-*}

if ! [[ $SEMVER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] 
then
    echo "ERROR! The VERSION $VERSION is not in semver format"
    exit 4
fi

if [ -z "${TARGETENV}" ]
then
    # Sono in production
    HOSTFILE="docker_host"
else
    # Sono in uno degli env di preprod
    HOSTFILE="docker_${TARGETENV}_host"
fi

echo "HOSTFILE: $HOSTFILE"

echo "Deploying custom images"
SOURCE_DIR="${CI_PROJECT_DIR:-.}/customers/"
[[ -d "$SOURCE_DIR" ]] && find "$SOURCE_DIR" -name "$HOSTFILE" | while read -r file; do
    echo "Deploying a custom image for: $file";
    # Looking if there is a custom script
    DIRNAME=$(dirname "$file")
    IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend-$(basename "$DIRNAME"):$CI_COMMIT_TAG
    echo "$IMAGE_TAG_FRONTEND"

    DOCKER_HOST="$(cat "$file")"
    export DOCKER_HOST
    echo "HOST: $DOCKER_HOST"
    DOCKER_HOST_DOMAIN="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f1)"
    export DOCKER_HOST_DOMAIN
    echo "DOMAIN: $DOCKER_HOST_DOMAIN"
    DOCKER_HOST_PORT="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f2)"
    export DOCKER_HOST_PORT
    echo "PORT: $DOCKER_HOST_PORT"

    echo "Preparing target installer dir and rsync needed files into it"
    rsync -arvz -e "ssh -p $DOCKER_HOST_PORT" --rsync-path "mkdir -p $TARGET_DIR && /usr/bin/rsync" --progress --delete /etc/thecore/docker/./docker-compose.yml /etc/thecore/docker/./docker-compose.net.yml "$DIRNAME/./docker.env" "${DOCKER_HOST_DOMAIN}:$TARGET_DIR"
    export IMAGE_TAG_FRONTEND
    echo "IMAGE TAG FRONTEND: $IMAGE_TAG_FRONTEND"
    ssh -n "$DOCKER_HOST_DOMAIN" -p "$DOCKER_HOST_PORT" "
        echo Login to $CI_REGISTRY
        echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY || exit 1
        export IMAGE_TAG_FRONTEND=$IMAGE_TAG_FRONTEND
        echo CD into $TARGET_DIR
        cd $TARGET_DIR
        echo Testing Config
        docker compose -f docker-compose.yml -f docker-compose.net.yml --env-file docker.env config || exit 2
        echo Compose up
        docker compose -f docker-compose.yml -f docker-compose.net.yml --env-file docker.env up -d --remove-orphans --no-build || exit 3
        echo Cleaning Docker system
        docker system prune -f
        docker logout $CI_REGISTRY
        cd ..
        rm -rf $TARGET_DIR"
done

    