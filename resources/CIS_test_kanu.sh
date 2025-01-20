#!/bin/bash

Image=$Image
Threshold=$Threshold

Dev_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/
Dev_repo_test=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/testing/

echo $Image
name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/_[^$]*$/_CISFail_/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/$/_CISFail_/')
        fi
echo $name_tag_split
echo $name_tag_splitX
#hard_img=$name_First$name_tag_split && echo $hard_img
hard_imgX=$name_First$name_tag_splitX && echo $hard_imgX
hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img

echo "Custom Image: $hard_img"
Image_ID=$(docker images --filter="reference="$hard_img"" --quiet)
echo "Image_ID    : $Image_ID"
echo "==============================================================================================================================="
docker images | grep -is $Image_ID
echo "==============================================================================================================================="

docker ps -q -f status=running | xargs -r docker stop

docker run --memory 256m --cpu-shares 512 --security-opt=no-new-privileges --read-only --tmpfs "/run" --tmpfs "/tmp" --restart=on-failure:5 --health-cmd='stat /etc/passwd || exit 1' --pids-limit 100 -it --name image6-d "$Image_ID" /bin/bash &> /dev/null              \
|| \
docker run --memory 256m --cpu-shares 512 --security-opt=no-new-privileges --read-only --tmpfs "/run" --tmpfs "/tmp" --restart=on-failure:5 --health-cmd='stat /etc/passwd || exit 1' --pids-limit 100 -it --name image6 -d "$Image_ID" /bin/sh &> /dev/null              \
|| \
docker run --memory 256m --cpu-shares 512 --security-opt=no-new-privileges --read-only --tmpfs "/run" --tmpfs "/tmp" --restart=on-failure:5 --health-cmd='stat /etc/passwd || exit 1' --pids-limit 100 -it --name image6 -d --entrypoint /bin/bash "$Image_ID" &> /dev/null \
|| \
docker run --memory 256m --cpu-shares 512 --security-opt=no-new-privileges --read-only --tmpfs "/run" --tmpfs "/tmp" --restart=on-failure:5 --health-cmd='stat /etc/passwd || exit 1' --pids-limit 100 -it --name image6 --entrypoint /bin/sh "$Image_ID" &> /dev/null 

Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet)
echo " container_id: $Cont_ID"
docker ps -a | grep -is $Cont_ID

timestamp=$(date "+%F-%T")
timeformat=$(echo $timestamp | sed "s/:/_/g")

#workspace=$(pwd)
#echo -n "" > $workspace/DockerBenchOutput2.log

echo pwd

cd ../docker-bench && unzip -o docker-bench-security-1.6.0.zip > /dev/null 3>&1
chown -R jenprod:jenprod docker-bench-security-1.6.0 &&  chmod -R 750 docker-bench-security-1.6.0
cd docker-bench-security-1.6.0/
echo -n "" > DockerBenchOutput2.log
./docker-bench-security.sh -c container_images,container_runtime -i $hard_img,image6 > DockerBenchOutput2.log
chmod a+x DockerBenchOutput2.log

a=`cat DockerBenchOutput2.log | grep -i Score: | awk {'print $3'}`
echo $a
echo $Threshold
echo "================================================================================"
echo "Dockerbench Post Harden Score"
echo "================================================================================"
tail -6 DockerBenchOutput2.log | cut -d " " -f 2,3
check=$(cat DockerBenchOutput2.log | grep -i "checks:" | awk '{print $NF}')
score=$(cat DockerBenchOutput2.log | grep -i "score:" | awk '{print $NF}')
echo "check=$check"
echo "score=$score"
percent=$(echo "scale=2; 100*$score/$check" | bc)
echo "percentage compliance is $percent %"
echo "================================================================================"

if [ $a -ge $Threshold ];then
        echo "SUCCESS - Threshold score of $Threshold Achieved"
echo "================================================================================"
else
        echo "FAILURE - Threshold score of $Threshold Not Achieved"
echo "================================================================================"

        ## PROD push ##
        docker tag "$Image_ID" "$Dev_repo""$hard_imgX""$timeformat"
        Tagged_Image=$(docker images | grep -i "$name_tag_splitX$timeformat" | awk '{print $1,$2}' | tr " " ":")
        echo Tagged_Non-compliantImage = $Tagged_Image
        docker push "$Dev_repo""$hard_imgX""$timeformat"
                if [ $? == 0 ]; then
                docker rmi -f "$Dev_repo""$hard_imgX""$timeformat"
                fi

        ## Test push ##
        #docker tag "$Image_ID" "$Dev_repo_test""$name_First""$name_tag""$Hard_fail""$timeformat"
        #docker images | grep -i $Dev_repo_test
        #docker push "$Dev_repo_test""$name_First""$name_tag""$Hard_fail""$timeformat"
fi

docker ps -a | grep -is $Cont_ID
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
docker ps -a | grep -is $Cont_ID
docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
