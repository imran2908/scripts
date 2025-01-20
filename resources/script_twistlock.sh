#!/bin/bash

str="$1"
url="$2"
usr="$3"
pswd="$4"

IFS=','
read -ra ADDR <<<"$str"
echo "$ADDR"
for image in "${ADDR[@]}";
do
  echo "$image"
  
  image_name="$image"

  Image_ID=$(docker images --filter="reference="$image_name"" --quiet)
  echo "$Image_ID"
  if [ $Image_ID ]; then
    sudo chmod 777 /root/twistcli.20.12
    sudo /root/twistcli images scan  --address "$url" -u "$usr" -p "$pswd" --details "$Image_ID"
    sudo /root/twistcli images scan  --address "$url" -u "$usr" -p "$pswd" --details "$Image_ID" | grep 'results: PASS' &> /dev/null

    if [ $? == 0 ]; then
      echo "results: PASS"
    else
      echo "results: FAIL"
      exit 1
    fi
  else
    error= $(docker pull "$image_name" | grep results)
    echo "$error"
    exit 0
    
  fi

  
done
