#!/bin/bash
#new Image
Image=$1
stage_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage/
stage_repo_test=blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage/testing/
Base_Image=_base_


name_split=$(echo $Image | awk -F/ '{print $NF}')
name_First=$(echo $name_split | awk -F: '{print $1}')
name_tag=$(echo $name_split | awk -F: '{print $NF}')

timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

# Testing push
docker tag $Image "$stage_repo_test""$name_First":"$name_tag""$Base_Image""$timeformat"
docker push "$stage_repo_test""$name_First":"$name_tag""$Base_Image""$timeformat"
if [ $? == 0 ]; then
	docker rmi -f "$stage_repo_test""$name_First":"$name_tag""$Base_Image""$timeformat"
fi
