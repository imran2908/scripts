#!/bin/bash
Image=$1

Dev_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing
#Dev_repo_test=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/

echo "$Image"

timestamp=$(date "+%F-%T")
timeformat=$(echo _$timestamp | sed "s/:/_/g")
name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
        fi
echo $name_tag_split

## OCI image check ##

BASH_VAR=$( { docker run --rm -a stdout --entrypoint cat $Image /etc/os-release; } 2>&1 )
a=`echo $BASH_VAR | tr [:upper:] [:lower:] | grep "oci runtime create failed" | cut -f4 -d : | tr -d " "`
b=ociruntimecreatefailed
        if [[ "$a" == "$b" ]]; then
                Image_ID=$(docker images --filter="reference="$Image"" --quiet)
                hard_img=$name_First$name_tag_split && echo $hard_img
                docker tag $Image_ID "$hard_img"
                #docker tag $Image_ID "$Dev_repo""$hard_img""$timeformat"
        else
                hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img
                #docker tag $Image_ID "$Dev_repo""$hard_img""$timeformat"
        fi

Image_ID=$(docker images --filter="reference="$hard_img"" --quiet)
echo "Harden_Image_ID   :       $Image_ID"
Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet)
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
docker tag $Image_ID "$Dev_repo""$hard_img""$timeformat"
Tagged_Image=$(docker images | grep -i "$name_tag_split$timeformat" | awk '{print $1,$2}' | tr " " ":")
echo "============================================================================================================================"
echo HardenImage = $Tagged_Image
echo "============================================================================================================================"

## PROD push ##

docker push "$Dev_repo""$hard_img""$timeformat"
        if [ $? == 0 ]; then
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
                docker rmi -f "$Dev_repo""$hard_img""$timeformat"
        fi

## Test push ##
        #docker tag $Image_ID "$Dev_repo_test""$name_First""$name_tag""$Harden_1""$timeformat"
        #docker images | grep -i $Dev_repo_test
        #docker push "$Dev_repo_test""$name_First""$name_tag""$Harden_1""$timeformat"
