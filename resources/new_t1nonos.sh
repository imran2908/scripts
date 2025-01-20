#!/bin/bash

Image=$1

Home_dir=/home/
Cust_user=dockeruser
Home_dir+=$Cust_user
#echo "$Home_dir"
echo $Image
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
docker images | grep -i $Image_ID
#docker run --rm --entrypoint cat $Image_ID '/etc/os-release' | grep -i pretty_name
baseimageOS=$(docker run --rm -a stdout --entrypoint cat $Image_ID '/etc/os-release' | grep -i pretty_name | cut -d = -f 2)
echo "==================================================================================================================="
echo BaseImage_OS: $baseimageOS
echo "==================================================================================================================="


who=`docker run --rm -a stdout --entrypoint whoami $Image_ID | sed '/\S/!d'`
work_dir=`docker run --rm -a stdout --entrypoint pwd $Image_ID | sed '/\S/!d'`
        if [ -z $work_dir ]; then
                work_dir=`echo $Home_dir`
        else
                echo "base image pwd to be retained"
        fi

workspace=$(pwd)
cd $workspace

#d=$(echo $RANDOM | md5sum | head -c20; echo;)
#rnd=$(openssl rand -hex 64)
#echo "$rnd" > secret.txt
password=`python ./new_password-generator.py`
echo "$password" | tee secret.txt > /dev/null


file="./Dockerfile"
echo "From $Image" > $file
echo "ARG VCS_REF" >> $file
echo "LABEL \
        maintainer="DevSecOps_DTR_Core_Dev" \
        image.revision=$VCS_REF \
        image.created=`date -u +"%Y-%b-%d.%I:%M:%S.%p.%Z"`" >> $file
#echo "HEALTHCHECK CMD exit 0" >> $file
echo "USER 0" >> $file
echo "WORKDIR /tmp" >> $file
echo "COPY new_cis_no_os.sh ./" >> $file
echo "RUN --mount=type=secret,id=rt_psw \
        chmod a+wx new_cis_no_os.sh  && \
        ./new_cis_no_os.sh                      && \
        rm -rf ./*                              && \
        chmod -vR 1777 /tmp" >> $file
#echo "USER $who" >> $file
echo "WORKDIR $work_dir" >> $file
echo "USER $Cust_user" >> $file
#echo "WORKDIR $Home_dir" >> $file
#cat $file

name_split=$(echo $Image | awk -F/ '{print $NF}') && echo $name_split
name_First=$(echo $name_split | sed 's/:.*/:/') && echo $name_First
name_tag=$(echo $name_split | awk -F: '{print $NF}') && echo $name_tag
nsx=$(echo $name_split | sed -e 's/.*_\(.*\)_202.*/\1/') && echo $nsx
        if [ $nsx == harden -o $nsx == base ]; then
                name_tag_split=$(echo $name_tag | sed 's/_[^$]*$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/_[^$]*$/_BuildFail_/')
        else
                name_tag_split=$(echo $name_tag | sed 's/$/_harden/')
                name_tag_splitX=$(echo $name_tag | sed 's/$/_BuildFail_/')
        fi
echo $name_tag_split
echo $name_tag_splitX
hard_img=$name_First$name_tag_split && echo $hard_img
hard_imgX=$name_First$name_tag_splitX && echo $hard_imgX
#hard_img=$(docker images | grep -w "$name_tag_split" | awk '{print $1,$2}' | tr " " ":") && echo $hard_img
docker ps -q -f status=running | xargs -r docker stop
docker images -q | grep -oP '(?<='$hard_img').*' | xargs -r docker rmi -f <<< $hard_img
docker images -q -f dangling=true | xargs -r docker rmi -f

## custom Docker image build ##
DOCKER_BUILDKIT=1 docker build --no-cache --pull --build-arg VCS_REF=$(git rev-parse --short HEAD) --secret id=rt_psw,src=secret.txt -t "$hard_img" .
##docker build --no-cache --pull --build-arg VCS_REF=$(git rev-parse --short HEAD) -t "$hard_img" .
#docker build --no-cache --pull -t "$hard_img" .
#docker build --no-cache --pull --rm=false --build-arg http_proxy=http://cis-india-pitc-bangalore.corporate.ge.com:80 -t "$hard_img" .
        if [ $? == 0 ]; then
                echo "==================================================================================================================="
                echo "Harden Image: $hard_img"
                Image_ID=$(docker images --filter="reference="$hard_img"" --quiet)
                echo "Image_ID    : $Image_ID"
                size=$(docker images | grep -w $name_tag_split | awk '{print $NF}' | tr " " ":")
                echo "Size        : $size"
                echo "==================================================================================================================="
                docker images | grep -is $Image_ID
        else
                timestamp=$(date "+%F-%T")
                timeformat=$(echo $timestamp | sed "s/:/_/g")
                Dev_repo=blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/
                dang_img=$(docker images -q -f dangling=true)
                docker tag $dang_img "$Dev_repo""$hard_imgX""$timeformat"
                Dangling_Image=$(docker images | grep -i "$name_tag_splitX$timeformat" | awk '{print $1,$2}' | tr " " ":")
                echo Tagged_Non-compliantImage = $Dangling_Image
                docker push "$Dev_repo""$hard_imgX""$timeformat"
                        if [ $? == 0 ]; then
                                docker rmi -f "$Dev_repo""$hard_imgX""$timeformat"
                        fi
fi
