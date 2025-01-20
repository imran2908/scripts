#!/bin/bash
Image=$1

##Stage_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage/
##Stage_repo_test=blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage/testing/

Stage_repo=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-stage/
Stage_repo_test=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-stage/testing/


echo $Image
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet)
echo "Image_ID   : $Image_ID"

timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_base_'$timeformat'/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_base_'$timeformat'/')
        fi
echo $name_tag_split

## PROD push ##

docker tag $Image_ID "$Stage_repo""$name_First""$name_tag_split"
Tagged_Image=$(docker images | grep -i $name_tag_split | awk '{print $1,$2}' | tr " " ":")
echo Tagged_BaseImage = $Tagged_Image
docker push "$Stage_repo""$name_First""$name_tag_split"
        if [ $? == 0 ]; then
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
                docker rmi -f "$Stage_repo""$name_First""$name_tag_split"
        fi

## Test push ##

#docker tag $Image_ID "$Stage_repo_test""$name_First""$name_tag""$Base_Image""$timeformat"
#docker images | grep -i $Stage_repo_test
#docker push "$Stage_repo_test""$name_First""$name_tag""$Base_Image""$timeformat"

