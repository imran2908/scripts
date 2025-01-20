#!/bin/bash
str="$1"
IFS=','
read -ra ADDR <<<"$str"
echo "$ADDR"
for image in "${ADDR[@]}";
do
  docker pull "$image"
  name_split=$(echo $image | awk -F/ '{print $NF}')
  echo "$name_split"
  #name_FTP= $(echo $name_split | tr ':' '_')
  name_FTP=$(echo $name_split | awk -F: '{print $1,$NF}')
  echo "$name_FTP"
  #name_FTP=echo "${$name_split//:/'_'}"
  syft "$image" --scope all-layers -o table
  pwd
  syft "$image" --scope all-layers -o table > "$name_split"_syft_all_layers_table.txt
  cd ..
  pwd
  syft "$image" --scope all-layers -o table > "$name_FTP"_syft_all_layers_table.txt
  cd ./docker-bench
  pwd

  
  
done
