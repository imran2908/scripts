#!/bin/bash
## Define a Clean Up Job
clean_up_benchsecurity () {
   echo "Cleanup the container"
   docker stop Hardenimage && docker rm Hardenimage
   #echo "Cleanup the images"
   #docker rmi "$image_name" "$artifactory_url_Failbuild""$name_split"_Hard_Fail "$artifactory_url_Passbuild""$name_split"
   echo "Clean-up the logs"
   rm -r docker-bench-security.sh.log
}
DESIRED_SCORE=$1
Image=$2
echo "$DESIRED_SCORE"
echo "$Image"
export Image

## Run the docker-bench security script
sh ./docker-bench-security.sh -c $hardening_check
#rm -rf docker-bench-security.sh.log
## Use Docker Content Trust - ## Docker Benchmark
#export DOCKER_CONTENT_TRUST=1
#/bin/bash docker-bench-security.sh -l docker-bench-security.sh.log -c container_images,container_runtime -e check_4_2,check_4_3,check_4_4,check_4_11,check_5_1 > /dev/null 2>&1
DOCKER_BENCHMARK_SCORE=$(cat  docker-bench-security.sh.log | grep Score: | awk '{print $3}')
DOCKER_BENCHMARK_CHECKS=$(cat  docker-bench-security.sh.log | grep Checks: | awk '{print $3}')
echo "Image: $Image"
echo "==============================================================================="
echo "The Docker Benchmark score on $DOCKER_BENCHMARK_CHECKS checks is: $DOCKER_BENCHMARK_SCORE"
## FAIL THE BUILD IF SCORE IS LESS THAN 14
## echo "$Required_score"
if [ $DOCKER_BENCHMARK_SCORE -lt $DESIRED_SCORE ]
then
   echo "The docker benchmark compliance failed because the DOCKER_BENCHMARK_SCORE is less than $DESIRED_SCORE"
   echo "==============================================================================="
   echo "Please correct the Warnings. For reference hardened dockefile and docker-compose, visit this link"
   echo "--https://devcloud.swcoe.ge.com/devspace/display/CZJTA/Container+Lifecycle+Management+-+dTDR--"
   echo "==============================================================================="
## SHOW THE DOCKER BENCH WARNINGS GENERATED IF THE BUILD FAILS
   cat  docker-bench-security.sh.log | grep WARN 
   ##rm -rf docker-bench-security.sh.log
   #docker commit Harden_baseimage "$x"_Hard_Fail
   docker tag "$image_name" "$artifactory_url_Failbuild""$name_split"_Hard_Fail
   clean_up_benchsecurity
   
   
else
   echo "The docker benchmark compliance passed because the DOCKER_BENCHMARK_SCORE is greater than "$DESIRED_SCORE". Good Job!!"
   #docker commit Harden_baseimage "$x"_Hard_Pass
   docker tag "$image_name" "$artifactory_url_Passbuild""$name_split"
   echo "==============================================================================="
   
   clean_up_benchsecurity
   ##rm -rf docker-bench-security.sh.log
fi
