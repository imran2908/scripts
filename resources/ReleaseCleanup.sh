#!/bin/bash
HardenImage="$1"
IFS=','
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"

pwd
workspace=$(pwd)
rm -rf $workspace/Release_TwistlockOutput3.*

count=0
for Image in "${ADDR[@]}";do

                #name_split=$(echo $Image | awk -F/ '{print $NF}')
                #name_First=$(echo $name_split | awk -F: '{print $1}')
                #docker_images=$(docker images | grep -i $name_First)
                docker rmi -f $Image
                if [ $? == 0 ]; then
                        echo "$Image removed"
                else
                        exit 0
                fi
                count=$(($count+1))
                echo "$count"
                if [[ "$count" == '5' ]]; then
                        echo "Pipeline will delete only 5 Images"
                        break
                fi
done
