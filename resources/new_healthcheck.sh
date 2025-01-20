#!/bin/bash
check_local() {
command="cat ls echo touch chmod chown groupadd addgroup adduser useradd passwd mkdir grep rm rmdir cd pwd mv cp"
for i in $command; do
        if [[ -z `type $i` ]]; then
        echo "$i MISSING!!!"
else
        echo "$i found in location `which $i`"
fi
done
}
check_param(){
for i in $@; do
if [[ -z `type $i` ]]; then
        echo "$i MISSING!!!"
else
        echo "$i found in location `which $i`"
fi
done
}
check_fips(){
if [ `sysctl crypto.fips_enabled |awk '{print $3}'` == 1 ] || [ `cat /proc/sys/crypto/fips_enabled` == 1 ]; then
echo "FIPS is ENABLED on the image"
else
echo "FIPS is NOT ENABLED on the image"
fi
}
check_fips
check_local
(check_param $@)
