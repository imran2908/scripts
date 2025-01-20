#!/bin/bash

#apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade


# Upgrade Existing Packages
#DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

#echo "deb http://deb.debian.org/debian sid main" > /etc/apt/sources.list && apt-get update
#echo "# deb http://snapshot.debian.org/archive/debian/20220711T000000Z bullseye main" > /etc/apt/sources.list
#echo "deb http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list
#echo "# deb http://snapshot.debian.org/archive/debian-security/20220711T000000Z bullseye-security main" >> /etc/apt/sources.list
#echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list
#echo "# deb http://snapshot.debian.org/archive/debian/20220711T000000Z bullseye-updates main" >> /etc/apt/sources.list
#echo "deb http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list

#########################################################################
#       Enter script to remidiate vuln pkgs in below space only         #
#########################################################################

#########################################################################


#########################################
#       Hardening Script                #
#########################################
        group_check=$(cat /etc/group | grep -w docker | cut -d : -f 1)
        user_check=$(cat /etc/passwd | grep -i docker | cut -d : -f 1)
                if [[ $group_check == docker && $user_check == dockeruser ]]; then
                        echo "Non-root User,Group already added"
                else
## Create non-root user
                        USERNAME=dockeruser
                        USERID=9000
                        GROUP=docker
                        GID=9001
                        groupadd -g $GID $GROUP                                         \
                &&      useradd -u $USERID -g $GROUP -m -s /bin/sh $USERNAME            \
                &&      chown -R $USERID:$GID /home/$USERNAME                           \
                &&      sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow       \
                &&      echo "Non-root User,Group added"
                        # Remove interactive login shell for all except essential ones
                        sed -i -r '/^('"$USERNAME"'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd
                fi
## Assigning sudo permission to non-root user ##
## sudo utility check - install only if missing ##
sudo --help &> /dev/null
        if [[ $? != 0 ]]; then
                #yum update -y &> /dev/null; 
                yum install -y sudo &> /dev/null
        fi
echo dockeruser ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/dockeruser || echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
chmod -R 0440 /etc/sudoers.d/$USERNAME

# Upgrade Existing Packages
#DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Assign new password for Root
#password=$(awk '{print $1;}' secret.txt)
##password=$(cat secret.txt)
##echo -e "$password\n$password\n" | passwd root 
password=$(cat /run/secrets/rt_psw)
echo -e "$password\n$password\n" | passwd root
        if [[ $? != 0 ]]; then
                exit 1
        fi
        echo "Defaults    rootpw" >> /etc/sudoers                                                               
        echo "Defaults        env_reset,timestamp_timeout=0" >> /etc/sudoers

# Change the UID/GID of an existing container user
#      groupmod -g 9001 docker
#      usermod --uid 9000 --gid 9001 dockeruser

# Remove all from /passwd /shadow /group except essential ones
        sed -i -r '/^('"$USERNAME"'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/passwd      \
&&      sed -i -r '/^(dockeruser|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/shadow \
&&      sed -i -r '/^('"$GROUP"'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/group

# Avoid error `Only root may specify -c or -f` when using
# ForceCommand with `-f` option at non-root ssh login.
#chmod u-s /usr/sbin/login_duo || mn=1

# /etc/duo/login_duo.conf must be readable only by user 'dockeruser'.
#chown $USERID:$GID /etc/duo/login_duo.conf || mn=1
#chmod 0400 /etc/duo/login_duo.conf || mn=1

# Ensure strict ownership and perms.
#chown root:root /usr/bin/github_pubkeys || mn=1
#chmod 0555 /usr/bin/github_pubkeys || mn=1

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

# Remove "libtirpc" pkg
#apk del libtirpc-common || apt -y --allow-remove-essential remove libtirpc-common || mn=1

# Remove zlib
#find  /var/lib/dpkg/status   -name  zlib1g -o -delete && touch /var/lib/dpkg/status || mn=1

# Remove all but a handful of admin commands.
# Below cmd might break "apk|apt-get update". Run it only if absolutely necessary
#find /sbin /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete || find /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
# Below cmd causes "apt-get" to fail. Run it only if absolutely necessary
# find / -xdev -type d -perm /0002 -exec chmod o-w {} + && find / -xdev -type f -perm /0002 -exec chmod o-w {} +

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
        find $sysdirs -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d -exec chown 0:0 {} \; -exec chmod 0755 {} \;  ||  \
        find $sysdirs1 -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d -exec chown 0:0 {} \; -exec chmod 0755 {} \;

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

## gosu removal ##
#rm /opt/bitnami/common/bin/gosu


#export SUDO_FORCE_REMOVE=yes && apt-get purge -y --allow-remove-essential sudo
#apt -y autoremove &> /dev/null; apt-get clean; apt-get autoclean &> /dev/null

## remove private keys
#rm -f /usr/local/go/src/crypto/tls/testdata/example-key.pem
rm -rf /usr/local/go/src/crypto/tls/testdata/*.pem /usr/share/doc/python27-pygpgme-0.3/tests/keys/*.sec

