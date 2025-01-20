#!/bin/bash

HardenImage=$1
twistlock_user=$2
twistlock_pass=$3

IFS=','
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"

for Image in "${ADDR[@]}";do

                echo "Image_Name : $Image"
                docker pull $Image

                name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
                name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
                name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
                nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
                        if [ $nsx == harden -o $nsx == base ]; then
                                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
                                name_tag_splitX=$(echo $name_tag | sed 's/_[^$]*$/_ReleaseTwistlockFail_/')
                        else
                                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
                                name_tag_splitX=$(echo $name_tag | sed 's/$/_ReleaseTwistlockFail_/')
                        fi
                echo $name_tag_split
                echo $name_tag_splitX
                hard_img=$name_First$name_tag_split && echo $hard_img
                #hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img
                hard_imgX=$name_First$name_tag_splitX && echo $hard_imgX
                #echo "Custom Image      : $hard_img"
                Image_ID=$(docker images --filter="reference="$Image"" --quiet)
                echo "Image_ID  : $Image_ID"

                if [ $Image_ID ]; then
                        echo "Twistlock scan in progress..."
                #       twistcli images scan --address https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083 -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Release_TwistlockOutput3.log
                        twistcli images scan --address https://10.177.209.104:8083 -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Release_TwistlockOutput3.log
                                if [ $? == 0 ]; then
                                        echo "Scan complete"
                                        #head -2 Release_TwistlockOutput3.log && echo ""
                                        #tail -6 Release_TwistlockOutput3.log
                                        sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g" Release_TwistlockOutput3.log | grep -i -A7 --group-separator="" 'scan results for: image\|vulnerabilities found\|compliance'
                                else
                                        echo "Scan incomplete"
                                        exit 1
                                fi
                else
                        error= $(docker pull "$Image" | grep results)
                        echo "error : $Image_ID Unavailable"
                        exit 0
                fi
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

                expected_critical=0
                expected_high=0
                critical=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $2}' | awk -F "- " '{print $NF}')
                high=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $3}' | awk -F "- " '{print $NF}')

                if [ $critical -eq $expected_critical ] && [ $high -eq $expected_high ];then
                        echo "Twistlock scan Vulnerability critical value= $critical & high value= $high "
                else
                        echo "Twistlock scan Vulnerability critical value is greater than $expected_critical  .Failed!"
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                        Dev_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/
                        timestamp=$(date "+%F-%T")
                        timeformat=$(echo $timestamp | sed "s/:/_/g")
                        docker tag $Image_ID "$Dev_repo""$hard_imgX""$timeformat"
                        Tagged_Image=$(docker images | grep -i "$name_tag_splitX$timeformat" | awk '{print $1,$2}' | tr " " ":")
                        echo Tagged_Non-compliantImage = $Tagged_Image
                        docker push "$Dev_repo""$hard_imgX""$timeformat"
                                if [ $? == 0 ]; then
                                        docker rmi -f "$Dev_repo""$hard_imgX""$timeformat"
                               fi
                fi
done
