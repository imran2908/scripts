#!/bin/bash

Image=$1
twistlock_user=$2
twistlock_pass=$3

pwd

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

        
                docker ps -q -f status=running | xargs -r docker stop
                twistcli images scan --address "https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083" -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID"
