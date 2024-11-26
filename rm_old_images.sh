#! /bin/bash

# This Script will remove docker images less  than the buffer image count
# version: v1.0

logMSG () {
  mtype=$1
  time=$(date)

  echo "[ $time ] [ $mtype ] : $2"
  echo "[ $time ] [ $mtype ] : $2" >> ~/automation_scripts/logs/script.log
}

rm_img ()
{
  img=$1
  bufferImgCount=$2

  latest_tag=$(sudo docker images | grep -w $img | awk '{print $2}' | head -n 1)
  logMSG "INFO" "Latest   <$img:$latest_tag>"
  rm_tag_from=$((latest_tag - bufferImgCount ))
  logMSG "INFO" "Removing $img images with tags <= $rm_tag_from"

  count_tags=$(sudo docker images | grep -w $img | awk '{print $2}' | wc -l)
  iter=$((count_tags - bufferImgCount))


  for n in $(seq "$iter" -1 1);
    do
      logMSG "INFO" "Removing $img:$rm_tag_from"
      sudo docker rmi "$img:$rm_tag_from"
      logMSG "INFO" "Removed  $img:$rm_tag_from"
      rm_tag_from=$((rm_tag_from - 1))
  done

}

# main execution starts

logMSG "INFO" "+---------+ SCRIPT EXECUTING +---------+"

# Usage:   rm_img <image without tag> <bufferImgCount>
# example: rm_img docker.io/library/hello-world 3

rm_img 

logMSG "INFO" "+---------+ SCRIPT EXECUTED+---------+"

