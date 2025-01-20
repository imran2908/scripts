#!/bin/bash
Image=$1
echo "Image_Name : $Image"

docker pull "$Image"
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
echo "Image_ID   : $Image_ID"

name_split=$(echo $Image | awk -F/ '{print $NF}')
name_FTP=$(echo $name_split | awk -F: '{print $1,$NF}')


workspace=$(pwd)
echo -n "" > $workspace/Initial_TwistlockOutput1.log

echo "Pre-Harden Twistlock Scan"
echo "================================================================================"
if [ $Image_ID ]; then
        twistcli images scan --address https://abb480d1dfbc14767b1052701a2cb1c5-1746829079.us-east-1.elb.amazonaws.com:8083  --details "$Image_ID" >> Initial_TwistlockOutput1.log
        head -2 Initial_TwistlockOutput1.log
        tail -20 Initial_TwistlockOutput1.log | grep -i -A5 'Vulnerabilities found\|Compliance'
     
        if [ $? == 0 ]; then
                echo "results: PASS"
        else
                echo "results: FAIL"
                exit 1
        fi
else
    export error=$(docker pull "$Image" | grep Status)
    echo "$error"
    exit 0

fi

echo "================================================================================"


docker stop $(docker ps -aq)
docker run -dit --entrypoint=/bin/bash $Image_ID || docker run -dit --entrypoint=/bin/sh $Image_ID
Cont_ID=$(docker ps -a --filter="ancestor="$Image_ID"" --quiet)
docker ps -a | grep -i $Cont_ID

echo "================================================================================"

echo "Dockerbench Initial Score"
echo "================================================================================"

echo -n "" > DockerBenchOutput1.txt
sudo bash ./docker-bench-security.sh -c container_images,container_runtime > DockerBenchOutput1.log
chmod +x DockerBenchOutput1.log
tail -3 DockerBenchOutput1.log
echo "================================================================================"

check=$(cat DockerBenchOutput1.log | grep -i "checks:" | awk '{print $NF}')
echo "Checks: $check"
score=$(cat DockerBenchOutput1.log | grep -i "score:" | awk '{print $NF}')
echo "Score: $score"

percentage=$(echo "scale=2; 100*$score/$check" | bc)
echo "percentage compliance is $percentage %"

echo "================================================================================"

docker stop $Cont_ID && docker rm -f $Cont_ID
