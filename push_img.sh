#! /bin/bash

# This Script will push docker images less  than the buffer image count
# version: v1.0

logMSG () {
  mtype=$1
  time=$(date)

  echo "[ $time ] [ $mtype ] : $2"
  echo "[ $time ] [ $mtype ] : $2" >> ~/automation_scripts/logs/script.log
}

push_img ()
{
  img=$1
  bufferImgCount=$2

  latest_tag=$(sudo docker images | grep -w $img | awk '{print $2}' | head -n 1)
  logMSG "INFO" "Latest   <$img:$latest_tag>"
  push_tag_from=$((latest_tag - bufferImgCount ))
  logMSG "INFO" "Pushing $img images with tags <= $push_tag_from"

  count_tags=$(sudo docker images | grep -w $img | awk '{print $2}' | wc -l)
  iter=$((count_tags - bufferImgCount))


  for n in $(seq "$iter" -1 1);
    do
      logMSG "INFO" "Pushing $img:$push_tag_from"
      sudo docker push "$img:$push_tag_from"
      logMSG "INFO" "pushed $img:$push_tag_from"
      push_tag_from=$((push_tag_from - 1))
  done

}

# main execution starts

logMSG "INFO" "+---------+ SCRIPT EXECUTING +---------+"

# Usage:   push_img <image without tag> <bufferImgCount>
# example: push_img docker.io/library/hello-world 3

push_img $1 $2

logMSG "INFO" "+---------+ SCRIPT EXECUTED+---------+"


