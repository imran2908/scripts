#!/bin/bash

Image=$1

docker ps -q -f status=running | xargs -r docker stop
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
echo "Image_ID   : $Image_ID"
docker images | grep -is $Image_ID
docker run -dit --entrypoint=/bin/bash $Image_ID  &> /dev/null || docker run -dit --entrypoint=/bin/sh $Image_ID &> /dev/null
Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet)
docker ps -a | grep -is $Cont_ID

echo "================================================================================"
echo "Dockerbench Initial Score"
echo "================================================================================"


#workspace=$(pwd)
#echo -n "" > $workspace/DockerBenchOutput1.log
cd ../docker-bench && unzip -o docker-bench-security-1.5.0.zip > /dev/null 3>&1
chown -R jenprod:jenprod docker-bench-security-1.5.0 &&  chmod -R 750 docker-bench-security-1.5.0
cd docker-bench-security-1.5.0/
echo -n "" > DockerBenchOutput1.log
./docker-bench-security.sh -c container_images,container_runtime $Image > DockerBenchOutput1.log
chmod a+x DockerBenchOutput1.log

tail -6 DockerBenchOutput1.log | cut -d " " -f 2,3
check=$(cat DockerBenchOutput1.log | grep -i "checks:" | awk '{print $NF}')
score=$(cat DockerBenchOutput1.log | grep -i "score:" | awk '{print $NF}')
percentage=$(echo "scale=2; 100*$score/$check" | bc)
echo "percentage compliance is $percentage %"
echo "================================================================================"

docker ps -a | grep -is $Cont_ID
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
docker ps -a | grep -is $Cont_ID
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
