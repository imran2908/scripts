#!/bin/bash

Image=$1
twistlock_user=$2
twistlock_pass=$3

workspace=$(pwd)
echo -n "" > $workspace/Initial_TwistlockOutput1.log


docker pull "$Image"
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
echo "================================================================================"
echo "Image_Name : $Image"
echo "Image_ID   : $Image_ID"
size=$(docker images | grep -w $Image_ID | awk '{print $NF}' | tr " " ":")
echo "Size       : $size"
echo "================================================================================"
docker images | grep -is $Image_ID


echo "Twistlock Scan in progress..."

        if [ $Image_ID ]; then
                docker ps -q -f status=running | xargs -r docker stop
                #twistcli images scan --address "https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083" -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Initial_TwistlockOutput1.log
                twistcli images scan --address "https://10.177.209.104:8083" -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Initial_TwistlockOutput1.log
                        if [ $? == 0 ]; then
                                echo "Scan complete"
                                #head -2 Initial_TwistlockOutput1.txt  && echo ""
                                #tail -20 Initial_TwistlockOutput1.txt | grep -i -A5 'Vulnerabilities found\|compliance'
                                sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g" Initial_TwistlockOutput1.log | grep -i -A7 --group-separator="" 'scan results for: image\|vulnerabilities found\|compliance'
                        else
                                echo "Scan incomplete"
                                exit 1
                        fi
        else
                export error=$(docker pull "$Image" | grep Status)
                echo "$error"
                exit 0
        fi
        

echo "================================================================================"
