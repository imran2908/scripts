#!/bin/bash

Image=$1

Home_dir=/home/
Cust_user=dockeruser
Home_dir+=$Cust_user
workspace=$(pwd)

Image_ID=$(docker images --filter="reference="$Image"" --quiet)
docker images | grep -i $Image_ID
#docker rmi --force "$Image_ID" && docker rmi --force "$Image_ID"

cd $workspace

## Fetching value(s) supplied for parameter 'Package'
array=( "$@" )
arraylength=${#array[@]}
touch new_pkgs.file
for (( i=2; i<${arraylength}; i++ ));
do
   echo "${array[$i]}" >> new_pkgs.file
done

echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "Following Package(s) requested to install"
cat new_pkgs.file
echo "++++++++++++++++++++++++++++++++++++++++++++++"

## Random password generation
password=$(echo $RANDOM | md5sum | head -c20; echo;)
echo "$password" > pswd.txt
chmod +x pswd.txt
i=0
while read line
do
        pswdd[$i]="$line"
        i=$((i+1))
done < pswd.txt
#echo ""$image"_"$timestamp"_"$timeformat" ---> "$pswdd"" > password.txt
echo "$pswdd" > secret.txt
chmod +x secret.txt
#cp -p secret.txt $workspace
pwd

file="./Dockerfile"
echo "From $Image" > $file
echo "HEALTHCHECK CMD exit 0" >> $file
echo "USER root" >> $file
echo "WORKDIR /tmp" >> $file
#echo "ADD cis_debian_alpine.sh new_pkgs.file vuln_pkgs.txt pswd.txt /tmp/" >> $file
echo "ADD cis_debian_alpine.sh new_pkgs.file pswd.txt /tmp/" >> $file
#echo "RUN chmod a+x cis_debian_alpine.sh new_pkgs.file vuln_pkgs.txt pswd.txt" >> $file
echo "RUN chmod a+x cis_debian_alpine.sh new_pkgs.file pswd.txt" >> $file
echo "RUN sed -ie "s/https/http/g" /etc/apk/repositories && apk update || mn=1 && apk add --no-cache bash" >> $file
echo "RUN bash cis_debian_alpine.sh || sh cis_debian_alpine.sh" >> $file
echo "RUN sed -ie "s/http/https/g" /etc/apk/repositories" >> $file
#echo "RUN rm -rf cis_debian_alpine.sh new_pkgs.file vuln_pkgs.txt pswd.txt" >> $file
echo "RUN rm -rf cis_debian_alpine.sh new_pkgs.file pswd.txt" >> $file
echo "USER $Cust_user" >> $file
echo "RUN echo $Home_dir" >> $file
echo "WORKDIR $Home_dir" >> $file
#cat $file

Harden=_harden
Image+=$Harden

docker build --build-arg http_proxy=http://cis-india-pitc-bangalore.corporate.ge.com:80 -t "$Image" .

echo "==================================================================================================================="
echo "Custom Image      : $Image"
Image_ID=$(docker images --filter="reference="$Image"" --quiet)
echo "Custom Image_ID   : $Image_ID"
echo "==================================================================================================================="
docker images | grep -i $Image_ID

