#!/bin/bash
HardenImage="$1"
IFS=','
echo "$HardenImage"
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"



timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

count=0
echo "Release Artifactory Push "
echo "******************************************************************************************"
for Image in "${ADDR[@]}";do

        name_split=$(echo $Image | awk -F/ '{print $NF}')
        name_First=$(echo $name_split | awk -F: '{print $1}')
        name_tag=$(echo $name_split | awk -F: '{print $NF}')
        time_tag=$( echo $Image| cut --complement -d ":" -f 1 | cut --complement -d "_" -f 4,5,6)

                echo "==================================================================================================================="
        #Note: docker-cyberlab-dev is used for test instead of docker-cyberlab-release
        #docker tag "$Image" blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag""_""$timeformat"
        #docker push blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag""_""$timeformat"

        docker tag "$Image" blr-artifactory.cloud.health.ge.com/docker-cyberlab-release/"$name_First":"$time_tag""_""$timeformat"
        docker push blr-artifactory.cloud.health.ge.com/docker-cyberlab-release/"$name_First":"$time_tag""_""$timeformat"

        #ReleaseImage=$(docker images | grep blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/$name_First | awk '{print $1,$2}' | tr " " ":")
        ReleaseImage=$(docker images | grep blr-artifactory.cloud.health.ge.com/docker-cyberlab-release/$name_First | awk '{print $1,$2}' | tr " " ":")
        echo "ReleaseImage = $ReleaseImage"
        if [ $? == 0 ];then
            #docker rmi -f blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag""_""$timeformat"
            docker rmi -f blr-artifactory.cloud.health.ge.com/docker-cyberlab-release/"$name_First":"$time_tag""_""$timeformat"
        fi
        echo "=================================================================================================================="



        count=$(($count+1))
                        echo "$count"
                        if [[ "$count" == '5' ]]; then
                                echo "Pipeline will push only 5 Images"
                                break
                        fi
done
