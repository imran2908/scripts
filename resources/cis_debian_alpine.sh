#!/bin/bash

#set -x

# Set HTTPS as default to download packages (Alpine only)
#sed -ie "s/https/http/g" /etc/apk/repositories

#apk upgrade

#apk add --repository http://mirror.yandex.ru/mirrors/alpine/v3.16/main --upgrade --allow-untrusted openssl curl ncurses pcre2 git
#apk add --repository http://mirror.yandex.ru/mirrors/alpine/edge/main --upgrade --allow-untrusted curl

## Install a Package
pwd
i=0
while read line
do
        array[$i]="$line"
        i=$((i+1))
done < new_pkgs.txt
#array=( "$@" )
arraylength=${#array[@]}
if [ ${array[0]} == 0 ]; then
echo "+++++++++++++ No package(s) requested to install ++++++++++++++"
#apk update && apk upgrade
else
for (( i=0; i<${arraylength}; i++ ));
do
   echo "+++++++++++ Package '${array[$i]}' being installed +++++++++++++"
#apk update && apk upgrade && apk add --repository http://nl.alpinelinux.org/alpine/edge/main --upgrade ${array[$i]}
apk add  ${array[$i]}
#apk list --installed | grep -i ${array[$i]}
echo "+++++++++ Package '${array[$i]}' installed successfully ++++++++++"
done
fi

## Upgrade Existing Package ##
i=0
while read line
do
        array[$i]="$line"
        i=$((i+1))
done < vuln_pkgs.txt

arraylength=${#array[@]}

if [[ ${array[0]} == 0 ]]; then
echo "+++++++++++ No packages to upgrade +++++++++++"
else
for (( i=0; i<${arraylength}; i++ ));
do
   echo "Is package '${array[$i]}' present in base image?"
#apk -e info ${array[$i]} && apk -L info ${array[$i]}
apk list --installed | grep -i ${array[$i]}
#if [[ $? == 0 ]]; then
x=$(apk list --installed | grep -i ${array[$i]} | awk -F" " '{print $1}') && echo $x
xy=$(echo $x | awk -F- '{print $2$3}') && echo $xy
xyz=$(echo $xy | sed -e 's/\.//g') && echo $xyz
xyza=$(echo $xyz | sed -e 's/[a-z]//g') && echo $xyza
echo "+++++++++++++ Package '${array[$i]}' present in base image, now being checked for upgrade ++++++++++++++"
apk add --repository http://mirror.yandex.ru/mirrors/alpine/edge/main --upgrade --allow-untrusted ${array[$i]}
apk list --installed | grep -i ${array[$i]}
a=$(apk list --installed | grep -i ${array[$i]} | awk -F" " '{print $1}') && echo $a
ab=$(echo $a | awk -F- '{print $2$3}') && echo $ab
abc=$(echo $ab | sed -e 's/\.//g') && echo $abc
abcd=$(echo $abc | sed -e 's/[a-z]//g') && echo $abcd
if [[ $xyza -ne $abcd ]]; then
echo "+++++++++++++ Package '${array[$i]}' upgraded successfully ++++++++++++++"
echo "==================================================================================================="
else
echo "+++++++++++++ Package '${array[$i]}' is already latest version, upgrade skipped ++++++++++++++"
echo "==================================================================================================="
fi
#else
#echo "Package '${array[$i]}' not present in base image, upgrade skipped"
echo "==================================================================================================="
#fi
done
fi

# Create non-root user
USERNAME=dockeruser
USERID=9000
GROUP=docker
GID=9001
        addgroup -g $GID -S $GROUP || groupadd -g $GID $GROUP
        adduser -u $USERID -G $GROUP -h /home/$USERNAME $USERNAME
#       sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow
        apk add --no-cache sudo
        echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
        chmod 0440 /etc/sudoers.d/$USERNAME

# Set HTTP back to default (Alpine only)
#sed -ie "s/http/https/g" /etc/apk/repositories

# Assign new password for Root

i=0
while read -s line
do
        password[$i]=$line
done < pswd.txt
echo -e "$password\n$password\n" | sudo passwd root || echo "$password\n$password\n" | sudo passwd root
        echo "Defaults    rootpw" >> /etc/sudoers
        echo "Defaults        env_reset,timestamp_timeout=0" >> /etc/sudoers

# Change the UID/GID of an existing container user
#       groupmod --gid $GID $GROUP                      \
#       usermod --uid $USERID --gid $GID $USERNAME      \
        chown -R $USERID:$GID /home/$USERNAME

# Remove unnecessary user accounts.
        sed -i -r '/^('$GROUP'|root|nginx|nobody|nogroup)/!d' /etc/group                                                \
&&      sed -i -r '/^('$USERNAME'|root|nginx|nobody)/!d' /etc/passwd                                                    \
&&      sed -i -r '/^('$USERNAME'|root|nginx|nobody):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd                   \
&&      sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow


# Avoid error `Only root may specify -c or -f` when using
# ForceCommand with `-f` option at non-root ssh login.
# https://www.duosecurity.com/docs/duounix-faq#can-i-use-login_duo-to-protect-non-root-shared-accounts,-or-can-i-do-an-install-without-root-privileges?
chmod u-s /usr/sbin/login_duo || mn=1

# /etc/duo/login_duo.conf must be readable only by user 'dockeruser'.
chown $USERID:$GID /etc/duo/login_duo.conf || mn=1
chmod 0400 /etc/duo/login_duo.conf || mn=1

# Ensure strict ownership and perms.
chown root:root /usr/bin/github_pubkeys || mn=1
chmod 0555 /usr/bin/github_pubkeys || mn=1

# To be informative after successful login.
        echo -e "\n\nApp container image built on $(date)." > /etc/motd \
||      echo "\n\nApp container image built on $(date)." > /etc/motd

# Moduli Configuration
moduli=/etc/ssh/moduli
if [[ -f ${moduli} ]]; then
  cp ${moduli} ${moduli}.orig
  awk '$5 >= 2000' ${moduli}.orig > ${moduli}
  rm -f ${moduli}.orig
fi

# Remove existing crontabs, if any.
rm -fr /var/spool/cron
rm -fr /etc/crontabs
rm -fr /etc/periodic
rm -fr /opt/bitnami

# Remove "libtirpc" pkg
#apk del libtirpc-common || apt -y --allow-remove-essential remove libtirpc-common || mn=1

# Remove zlib
#find  /var/lib/dpkg/status   -name  zlib1g -o -delete && touch /var/lib/dpkg/status || mn=1

# Remove all but a handful of admin commands.
# Below cmd removes "apk|apt-get update". Run it only if absolutely necessary
#find /sbin /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete || find /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
        find / -xdev -type d -perm /0002 -exec chmod o-w {} + \
&&      find / -xdev -type f -perm /0002 -exec chmod o-w {} +

# Remove interactive login shell for everybody but dockeruser.
#sed -i -r '/^root:/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

sysdirs="
  /bin
  /etc
  /lib
  /sbin
  /usr
"
sysdirs1="
  /bin
  /etc
  /lib
  /usr
"

# Remove apk configs.
# Below cmd removes "apk|apt-get update". Run it only if absolutely necessary
#find $sysdirs -xdev -regex '.*apk.*' -exec rm -fr {} + || find $sysdirs1 -xdev -regex '.*apt.*' -exec rm -fr {} +

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
        find $sysdirs -xdev -type f -regex '.*-$' -exec rm -f {} + \
||      find $sysdirs1 -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
#find $sysdirs -xdev -type d  -exec chown root:root {} \;  -exec chmod 0755 {} \; || find $sysdirs1 -xdev -type d  -exec chown root:root {} \;  -exec chmod 0755 {} \;
        find $sysdirs -xdev -type d             \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {} \;   ||     \
        find $sysdirs1 -xdev -type d            \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {}      \;

# Remove all suid files.
# Below cmd disables switch user. Run it only if absolutely necessary
#find $sysdirs -xdev -type f -a -perm /4000 -delete || find $sysdirs1 -xdev -type f -a -perm /4000 -delete

# Remove other programs that could be dangerous.
#find $sysdirs -xdev \( -name hexdump -o  -name chgrp -o -name chmod -o -name chown -o -name ln -o -name od -o -name strings -o -name su \)  -exec rm -fr {} + || find $sysdirs1 -xdev \( -name hexdump -o  -name chgrp -o -name chmod -o -name chown -o -name ln -o -name od -o -name strings -o -name su \) -delete
#find $sysdirs -xdev \( -name hexdump -o  -name chgrp -o -name chown -o -name ln -o -name od -o)  -exec rm -fr {} + || find $sysdirs1 -xdev \( -name hexdump -o  -name chgrp -o -name chown -o -name ln -o -name od -o) -delete
        find $sysdirs -xdev \( -name hexdump -o  -name chgrp -o  -name ln -o -name od -o -name mn=1 \)  -exec rm -fr {} + || \
        find $sysdirs1 -xdev \( -name hexdump -o  -name chgrp -o  -name ln -o -name od -o -name mn=1 \) -exec rm -fr {} +

# Remove init scripts since we do not use them.
#rm -fr /etc/init.drm -fr /lib/rc
#rm -fr /etc/conf.d
#rm -fr /etc/inittab
#rm -fr /etc/runlevels
#rm -fr /etc/rc.conf

# Remove kernel tunables since we do not need them.
#rm -fr /etc/sysctl*
#rm -fr /etc/modprobe.d
#rm -fr /etc/modules
#rm -fr /etc/mdev.conf
#rm -fr /etc/acpi

# Remove root homedir since we do not need it.
#rm -fr /root

# Remove fstab since we do not need it.
#rm -f /etc/fstab

# Remove broken symlinks (because we removed the targets above).
        find $sysdirs -xdev -type l -exec test ! -e {} \; -delete \
||      find $sysdirs1 -xdev -type l -exec test ! -e {} \; -delete

# To fix the warning "su: must be suid to work properly" in 'kong' image with Alpine
chmod 4755 /bin/su

apk upgrade --repository http://mirror.yandex.ru/mirrors/alpine/edge/main --allow-untrusted curl zlib libxml2 libcurl
apk del --force --purge libpng nginx-module-image-filter
apk add --no-cache --virtual libpng
apk add --no-cache --virtual freetype libbz2 libjpeg-turbo libwebp
apk add --no-cache --virtual nginx-module-image-filter
apk add --no-cache --virtual libgd

#apk upgrade --repository http://mirror.yandex.ru/mirrors/alpine/edge/main --allow-untrusted
apk del --force --purge bash sudo

# Delete Private Key
rm -f /usr/local/go/src/crypto/tls/testdata/example-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/cert-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/cert_chains/ca-cert-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/cert_chains/cert-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/with_ca/ca-cert-key-pass.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/with_ca/ca-cert-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/with_ca/cert-key-pass.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/with_ca/cert-key.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/without_ca/cert-key-pass.pem
rm -f /usr/lib/ruby/gems/3.1.0/gems/fluentd-1.15.3/test/plugin_helper/data/cert/without_ca/cert-key.pem
