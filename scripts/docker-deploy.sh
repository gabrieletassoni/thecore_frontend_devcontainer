#!/bin/bash -e

echo "COMMIT TAG: ${CI_COMMIT_TAG}"
VERSION=${CI_COMMIT_TAG}

# Used to not have conflicting installations
UUID=$(cat /proc/sys/kernel/random/uuid)
TARGET_DIR="/tmp/installers/$UUID"

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
    exit 3
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

DEPTARGETS="customers"
if ! [ -d $DEPTARGETS ]
then
    echo "ERROR! This script must be run from the directory containing $DEPTARGETS folder."
    exit 2
fi

cd $DEPTARGETS
for PROVIDER in *
do 
    if [ -f "$PROVIDER/$HOSTFILE" ]
    then
        echo "$PROVIDER has a $HOSTFILE file, let's see if it also has customers"
        DOCKER_HOST="$(cat "$PROVIDER/$HOSTFILE")"
        export DOCKER_HOST
        DOCKER_HOST_DOMAIN="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f1)"
        export DOCKER_HOST_DOMAIN
        DOCKER_HOST_PORT="$(echo "$DOCKER_HOST" | cut -d'/' -f3 | cut -d':' -f2)"
        export DOCKER_HOST_PORT
        echo "Preparing target installer dir"
        ssh "$DOCKER_HOST_DOMAIN" -p "$DOCKER_HOST_PORT" "
            docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY || exit 1
            mkdir -p $TARGET_DIR"
        rsync -arvz -e "ssh -p $DOCKER_HOST_PORT" --progress --delete /etc/thecore/docker/docker-compose.yml /etc/thecore/docker/docker-compose.net.yml "$PROVIDER" "${DOCKER_HOST_DOMAIN}:$TARGET_DIR"
        for CUSTOMER in "$PROVIDER"/*.env
        do
            echo "  - found $CUSTOMER doing the remote up thing on $DOCKER_HOST"
            if [[ -f "$PROVIDER"/image ]]
            then
                IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend-$(head -c -1 "$PROVIDER"/image):$CI_COMMIT_TAG
            else
                IMAGE_TAG_FRONTEND=${CI_REGISTRY_IMAGE}/frontend:$CI_COMMIT_TAG
            fi
            export IMAGE_TAG_FRONTEND
            echo "IMAGE TAG FRONTEND: $IMAGE_TAG_FRONTEND"
            ssh "$DOCKER_HOST_DOMAIN" -p "$DOCKER_HOST_PORT" "
                export IMAGE_TAG_FRONTEND=$IMAGE_TAG_FRONTEND
                echo CD into $TARGET_DIR
                cd $TARGET_DIR
                echo Testing Config for $CUSTOMER
                docker compose -f docker-compose.yml -f docker-compose.net.yml --env-file $CUSTOMER config || exit 3
                echo Compose up on $CUSTOMER
                docker compose -f docker-compose.yml -f docker-compose.net.yml --env-file $CUSTOMER up -d --remove-orphans --no-build || exit 2
                echo Cleaning Docker system
                docker system prune -f
                docker logout $CI_REGISTRY
                rm -rf $TARGET_DIR"
        done
    fi
done
    