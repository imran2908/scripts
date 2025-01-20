#!/bin/bash

Image=$1
twistlock_user=$2
twistlock_pass=$3

#Dev_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/
#Dev_repo_test=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/

Dev_repo=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/
Dev_repo_test=blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/testing/

workspace=$(pwd)
echo -n "" > $workspace/Post_TwistlockOutput2.log

timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

echo $Image
name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/_[^$]*$/_TwistlockFail_/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/$/_TwistlockFail_/')
        fi
echo $name_tag_split
echo $name_tag_splitX
#hard_img=$name_First$name_tag_split && echo $hard_img
hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img
hard_imgX=$name_First$name_tag_splitX && echo $hard_imgX

echo "==================================================================================================================="
echo "Custom Image      : $hard_img"
Image_ID=$(docker images --filter="reference="$hard_img"" --quiet)
echo "Custom Image_ID   : $Image_ID"
echo "==================================================================================================================="

echo "Twistlock scan in progress..."

        if [ $Image_ID ]; then
                #twistcli images scan --address "https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083" -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Post_TwistlockOutput2.log
                twistcli images scan --address "https://10.177.209.104:8083" -u "$twistlock_user" -p "$twistlock_pass" --details "$Image_ID" >> Post_TwistlockOutput2.log
                        if [ $? == 0 ]; then
                                echo "Scan complete"
                                #head -2 Post_TwistlockOutput2.txt && echo ""
                                #tail -20 Post_TwistlockOutput2.txt | grep -i -A5 'Vulnerabilities found\|compliance'
                                sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g" Post_TwistlockOutput2.log | grep -i -A7 --group-separator="" 'scan results for: image\|vulnerabilities found\|compliance'
                        else
                                echo "Scan incomplete"
                        exit 1
                        fi
        else
                error=$(docker pull "$hard_img" | grep results)
                echo $error
                exit 0
        fi

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
expected_critical=0
expected_high=0

critical=$( cat Post_TwistlockOutput2.log | grep -m1 "Vulnerabilities " | awk -F, '{print $2}' | awk -F "- " '{print $NF}')
high=$( cat Post_TwistlockOutput2.log | grep -m1 "Vulnerabilities " | awk -F, '{print $3}' | awk -F "- " '{print $NF}')

#if [ $critical == $expected_critical ];then
if [ $critical == $expected_critical ] && [ $high == $expected_high ];then

        echo "Post Hardening Twistlock scan critical value= $critical & high value= $high "
else
        echo "Post Hardening Twistlock scan Critical value $critical and High value $high are not Zero"


        ## PROD push ##
        docker tag $Image_ID "$Dev_repo""$hard_imgX""$timeformat"
        Tagged_Image=$(docker images | grep -i "$name_tag_splitX$timeformat" | awk '{print $1,$2}' | tr " " ":")
        echo Tagged_Non-compliantImage = $Tagged_Image
        docker push "$Dev_repo""$hard_imgX""$timeformat"
                if [ $? == 0 ]; then
                docker rmi -f "$Dev_repo""$hard_imgX""$timeformat"
                fi

        ## Test push ##
        #docker tag "$Image_ID" "$Dev_repo_test""$name_First""$name_tag""$TL_fail""$timeformat"
        #docker images | grep -i $Dev_repo_test
        #docker push "$Dev_repo_test""$name_First""$name_tag""$TL_fail""$timeformat"
fi
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
