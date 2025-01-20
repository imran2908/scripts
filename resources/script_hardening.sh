#!/bin/bash
str="$1"
str1="$2"
hardening_check="$3"
IFS=','
read -ra ADDR <<<"$str"
echo "$ADDR"
for image in "${ADDR[@]}";
do
  docker pull "$image"
  name_split=$(echo $image | awk -F/ '{print $NF}')
  echo "$name_split"
  echo "$str1"
  #cd ./resources/docker-bench
  
  
  image_name="$image"
  artifactory_url_Failbuild=hc-us-east-aws-artifactory.cloud.health.ge.com/docker-cyberlab-stage/
  artifactory_url_Passbuild=hc-us-east-aws-artifactory.cloud.health.ge.com/docker-cyberlab-release/
  score="$str1"
  export image_name
  export artifactory_url_Failbuild
  export artifactory_url_Passbuild
  export score
  export name_split
  export hardening_check
  Image_ID=$(docker images --filter="reference="$image_name"" --quiet)
  echo "$Image_ID"
  if [ $Image_ID ]; then
    #export DOCKER_CONTENT_TRUST=1
    docker run -d --restart=always --name=Hardenimage -p 8033:8033 "$image_name"
    chmod a+x ./Hardening_build.sh && ./Hardening_build.sh $str1 $image_name
  else
    error= $(docker pull "$image_name" | grep results)
    echo "$error"
    exit 0
  fi
  
  
done
