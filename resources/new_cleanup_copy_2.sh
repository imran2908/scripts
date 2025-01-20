#!/bin/bash
Image=$1

echo $Image
name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
        fi
echo $name_tag_split
#hard_img=$name_First$name_tag_split
hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":")

IFS=','
read -ra ADDR <<<"$hard_img"
echo "$ADDR"

#pwd
#workspace=$(pwd)
#rm -f $workspace/*.txt

#for hard_img in "${ADDR[@]}";do
                Image_ID=$(docker images --filter="reference="$hard_img"" --quiet) && echo $Image_ID
                Cont_ID=$(docker ps --filter="ancestor="$Image_ID"" --quiet) && echo $Cont_ID
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
                docker images -q | grep -i "$Image_ID" | xargs -r docker rmi -f
                if [ $? == 0 ]; then
                        echo "$ADDR removed"
                else
                        exit 0
                fi

                echo $Image
                Image_ID=$(docker images --filter="reference="$Image"" --quiet) && echo $Image_ID
                Cont_ID=$(docker ps --filter="ancestor=$Image_ID" --quiet) && echo $Cont_ID
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker stop
                docker ps -aq | grep -i "$Cont_ID" | xargs -r docker rm -f
                docker images -q | grep -i "$Image_ID" | xargs -r docker rmi -f
                docker images -q -f dangling=true | xargs -r docker rmi -f
                if [ $? == 0 ]; then
                        echo "$Image removed"
                else
                        exit 0
                fi
#done
