#! /usr/bin/bash

# Deploy POC application.
# Version v1.1
set -e 

# Application related variables
REPO_URL=https://<PAT-Token>@<git-url>
APP_NAME=<app-name> #example: ums
BRANCH=<branch-name> # example: main

# ECR variable
ECR_URL=<ecr-url> #example: 99999999999.dkr.ecr.ekr-southeast-1.amazonaws.com
ECR_REGISTRY=<ecr-registry> #example: ums
ECR_IMAGE="$ECR_URL/$ECR_REGISTRY" 

# YAML file (docker compose file)
YAML=<yaml-file-location> # example: ~/mm-compose.yaml

# Mendix docker buildpack related configurations
BUILDPACK_TAG=<buildpack-tag>  # example: v5.0.4
BUILDPACK_PATH=~/mendix-buildpack-$BUILDPACK_TAG

# AWS cli configs
AWS_ECR_REGION=ap-southeast-1
AWS_USR_NAME=AWS

# Customisation variables
CLONE_DEPTH=1  # Configure this if needed

# logs configuration
LOG_FOLDER_PATH=~/automation_scripts/logs 
LOG_FILE_PATH=$LOG_FOLDER_PATH/script.log

# check for log folder existence.
if [ -f "$LOG_FOLDER_PATH" ]
then
    echo "Logs folder exists"
else
    echo "logs folder is missing or deleted. Creating a log folder at $LOG_FOLDER_PATH"
    mkdir -p $LOG_FOLDER_PATH
fi
# check for log file existence.
if [ -f "$LOG_FILE_PATH" ]
then
    echo "Log file exists"
else
    echo "Log File is missing or deleted. Creating a log file at $LOG_FILE_PATH"
    touch $LOG_FILE_PATH
fi    

logMSG () 
{
    tdy=$(date) 
    name=$(whoami)
    msg=$1
    echo "[ $tdy ] $name : \"$msg\"" >> $LOG_FILE_PATH
    echo "[ $tdy ] $name : \"$msg\""
}

dockerLogin ()
{
    sudo aws ecr get-login-password --region $AWS_REGION | sudo docker login --username $AWS_USR_NAME --password-stdin $ECR_URL
}

checkBuildPack ()
{
    logMSG "Checking for Mendix BuildPack"
    if [ -d "$BUILDPACK_PATH" ]
    then
        logMSG "BuildPack $BUILDPACK_PATH exists"
    else
        logMSG "BuildPack doesn't exists"
        logMSG "Clone Mendix BuildPack"

        git clone --branch $BUILDPACK_TAG --config core.autocrlf=false https://github.com/mendix/docker-mendix-buildpack $BUILDPACK_PATH 
    fi
}

checkOutRepo ()
{
    # Remove any existing application clone
    rm -rf $BUILDPACK_PATH/$APP_NAME/

    logMSG "Cloning the application"
    git clone -b $BRANCH $REPO_URL $BUILDPACK_PATH/$APP_NAME --depth $CLONE_DEPTH
    
    if [ -d "$BUILDPACK_PATH/$APP_NAME" ]
    then
        logMSG "Cloned successfully"

        COMMIT_HASH=$(git -C $BUILDPACK_PATH/$APP_NAME log -n 1 --pretty=format:"%h")
        logMSG "Revision cloned: $COMMIT_HASH"

    else
        logMSG "Not Cloned"
        exit 1
    fi
}



buildImage () 
{
    # get current image deployed
    CURRENT_TAG=$(cat $YAML | grep /$ECR_REGISTRY: | awk -F ":" "{print \$3}")

    # New tage for this deployment.
    NEW_TAG=$((CURRENT_TAG + 1))

    # Build images
    cd $BUILDPACK_PATH

    logMSG "Checking rootfs-app image" # check mendix-rootfs:app image
    isapp=$(sudo docker images --filter=reference="mendix-rootfs:app-$BUILDPACK_TAG" --format '{{.Tag}}')
    if [ "$isapp" == "app-$BUILDPACK_TAG" ]
    then
        logMSG "rootfs-app image exists"
    else
        logMSG "rootfs-app image doesn't exist, creating it"
        sudo docker build -t mendix-rootfs:app-$BUILDPACK_TAG -f ./rootfs-app.dockerfile .
    fi

    logMSG "Checking rootfs-builder image" # check mendix-rootfs:builder image
    isbuilder=$(sudo docker images --filter=reference="mendix-rootfs:builder-$BUILDPACK_TAG" --format '{{.Tag}}')
    if [ "$isbuilder" == "builder-$BUILDPACK_TAG" ]
    then
        logMSG "rootfs-builder image exists"
    else
        logMSG "rootfs-builder image doesn't exist, creating it"
        sudo docker build -t mendix-rootfs:builder-$BUILDPACK_TAG -f ./rootfs-builder.dockerfile .
    fi

    # build application image
    logMSG "Building app image" 
    cd $BUILDPACK_PATH
    sudo docker build --build-arg BUILD_PATH="$APP_NAME" --build-arg ROOTFS_IMAGE=mendix-rootfs:app-$BUILDPACK_TAG --build-arg BUILDER_ROOTFS_IMAGE=mendix-rootfs:builder-$BUILDPACK_TAG -t $ECR_IMAGE:$NEW_TAG .
}

pushImage () {
    # push the current build
    logMSG "Pushing image to ECR"
    sudo docker push "$ECR_IMAGE:$NEW_TAG"
    logMSG "Image pushed to ECR"
}

deployApp () 
{
    # Change the image tag in tha yaml file.
    TAG=$(cat $YAML | grep /$ECR_REGISTRY:)
    logMSG "Before yaml is changed $TAG"
    sed -i "s/$ECR_REGISTRY:$CURRENT_TAG/$ECR_REGISTRY:$NEW_TAG/" $YAML
    TAG=$(cat $YAML | grep /$ECR_REGISTRY:)
    logMSG "After yaml is chaged $TAG"

    # Turn up the application
    sudo docker compose -f $YAML up -d

    # Remove Old image
    sudo docker rmi "$ECR_IMAGE:$CURRENT_TAG"
}

#main script
main ()
{
    logMSG "--------- Deploying $APP_NAME ---------"
    dockerLogin
    checkBuildPack
    checkOutRepo
    buildImage
    pushImage
    deployApp
    logMSG "--------- Completed Script ---------"
}

#exeuction starts here
main


