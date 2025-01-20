#!/bin/bash

clean_up_job () {
    #echo "Cleanup the container"
    #docker stop Harden_baseimage && docker rm Harden_baseimage
    echo "Cleanup the images"
    docker rmi "$image_name" "$artifactory_url_Failbuild""$name_split"_Hard_Fail "$artifactory_url_Passbuild""$name_split"
    echo "Clean-up the logs"
    rm -rf docker-bench-security.sh.log
}


str="$1"
usr_pswd="$2"
#pswd="$3"

IFS=','
read -ra ADDR <<<"$str"
echo "$ADDR"
for image in "${ADDR[@]}";
do
  echo "$image"
  name_split=$(echo $image | awk -F/ '{print $NF}')
  echo "$name_split"
  
  image_name="$image"
  artifactory_url_Failbuild=hc-us-east-aws-artifactory.cloud.health.ge.com/docker-cyberlab-stage/
  artifactory_url_Passbuild=hc-us-east-aws-artifactory.cloud.health.ge.com/docker-cyberlab-release/
  #export image_name
  #export artifactory_url
  #export artifactory_url_Failbuild
  #export artifactory_url_Passbuild

  
  unset https_proxy
  unset http_proxy
  
  docker login hc-us-east-aws-artifactory.cloud.health.ge.com -u "$usr_pswd" -p "$usr_pswd"
  echo "==============================================================================="
  gepse-docker push "$artifactory_url_Passbuild""$name_split"
  gepse-docker push "$artifactory_url_Failbuild""$name_split"_Hard_Fail
  echo "==============================================================================="
  echo 'Verifying signed image'
  gepse-docker trust inspect --pretty "$artifactory_url_Passbuild""$name_split"
  gepse-docker trust inspect --pretty "$artifactory_url_Failbuild""$name_split"_Hard_Fail

  echo "==============================================================================="

  clean_up_job
  
done
