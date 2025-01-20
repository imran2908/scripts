#!/bin/bash

HardenImage="$1"

IFS=','
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"
Rel_repo=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-release/
#Rel_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-release/
##Rel_repo=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/testing/shridhar/
timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

for Image in "${ADDR[@]}";do

        name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
        name_First=$(echo $name_split | sed 's/:.*//') && echo $name_First
        name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
        nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
        fi
        echo $name_tag_split

        hard_img=$name_First$name_tag_split && echo $hard_img
        #hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img
        Image_ID=$(docker images --filter="reference="$Image"" --quiet)
        Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet)
        echo "Image_ID : $Image_ID"

        docker tag $Image_ID "$Rel_repo""$name_split"
        docker rmi -f $Image
        ReleaseImage=$(docker images | grep -i "$name_tag" | awk '{print $1,$2}' | tr " " ":")
        ImageSize=$(docker images --format "{{.Size}}"  $ReleaseImage)
        critical=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $2}' | awk -F "- " '{print $NF}')
        high=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $3}' | awk -F "- " '{print $NF}')
        echo "================================================================================================================================="
        echo "ReleaseImage = $ReleaseImage"
        echo "ImageSize = $ImageSize"
        echo "VulCount = Critical $critical, High $high"
        echo "================================================================================================================================="
        docker push "$Rel_repo""$name_split"
                if [ $? == 0 ];then
                        docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
                        docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
                        docker rmi -f "$Rel_repo""$name_split"
                fi
done
