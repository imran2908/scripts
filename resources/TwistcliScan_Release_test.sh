#!/bin/bash
HardenImage="$1"
IFS=','
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"

count=0
echo "Post Harden Twistlock Scan"
echo "******************************************************************************************"
for Image in "${ADDR[@]}";do

                echo "Image_Name : $Image"

                Image_ID=$(docker images --filter="reference="$Image"" --quiet)
                echo "Image_ID   : $Image_ID"

                name_split=$(echo $Image | awk -F/ '{print $NF}')
                name_First=$(echo $name_split | awk -F: '{print $1}')
                name_tag=$(echo $name_split | awk -F: '{print $NF}')

                timestamp=$(date "+%F-%T")
                timeformat=$(echo $timestamp | sed "s/:/_/g")

                if [ $Image_ID ]; then
                        twistcli images scan --address https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083 --details "$Image_ID" >> Release_TwistlockOutput3.log
                        tail -6 Release_TwistlockOutput3.log
                else
                        error= $(docker pull "$Image" | grep results)
                        echo "error : Image_ID Unavailable"
                        exit 0

                fi
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"


                expected_critical=0
                expected_high=0
                critical=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $2}' | awk -F "- " '{print $NF}')
                high=$( cat Release_TwistlockOutput3.log | grep -m1 "Vulnerabilities " | awk -F, '{print $3}' | awk -F "- " '{print $NF}')

                if [ $critical -eq $expected_critical ] && [ $high -eq $expected_high ];then
                #if [ $critical -ge $expected_critical ];then
                #       echo "Twistlock scan Vulnerability critical value= $expected_critical "
                                echo "Twistlock scan Vulnerability critical value= $critical & high value= $high "
                else
                                echo "Twistlock scan Vulnerability critical value is greater than $expected_critical  .Failed!"
                                time_tag=$(echo $Image | cut --complement -d ":" -f 1 | cut --complement -d "_" -f 3,4,5)

                                #docker tag "$Image" blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"
                                #docker push blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"
                                docker tag "$Image" blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"
                                docker push blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"

                                if [ $? == 0 ];then
                                         #docker rmi -f blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"
                                          docker rmi -f blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/"$name_First":"$time_tag"_ReleaseTwistlockFail_"$timeformat"
                                fi

                fi



                echo "======================================================================================================="
                count=$(($count+1))
                echo "$count"
                if [[ "$count" == '5' ]]; then
                        echo "Pipeline will scan only 5 Images"
                        break
                fi
done
echo "******************************************************************************************"

