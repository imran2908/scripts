#!/bin/bash
HardenImage="$1"
#HardenImage=`echo $HardenImage | sed 's/ *$//g'`
IFS=','
read -ra ADDR <<<"$HardenImage"
echo "$ADDR"

count=0
for Image in "${ADDR[@]}";do
        docker pull "$Image"
        count=$(($count+1))
        echo "$count"
        if [[ "$count" == '5' ]]; then
                echo "Pipeline will process only 5 Images"
                break
        fi
done
