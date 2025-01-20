#!/bin/sh

## revert to 'http' from 'https' to prevent permission issue while updating pkg ##
## Using Host ca-certificates for the repos##
#apk update &> /dev/null
#if [[ $? != 0 ]]; then
 #       sed -ie s/https/http/g /etc/apk/repositories
 #       apk update &> /dev/null
#fi

#########################################################################
#       Enter script to remidiate vuln pkgs in below space only         #
#########################################################################

#apk upgrade --repository=http://dl-cdn.alpinelinux.org/alpine/v3.16/main --allow-untrusted --no-cache busybox zlib &> /dev/null \
#apk upgrade  --repository http://mirror.yandex.ru/mirrors/alpine/edge/community --allow-untrusted --no-cache libssl1.1 libcrypto1.1 libcurl ncurses-terminfo-base &> /dev/null
#apk upgrade --repository http://mirror.yandex.ru/mirrors/alpine/edge/community --allow-untrusted --no-cache sudo &> /dev/null
#apk upgrade  --repository http://mirror.yandex.ru/mirrors/alpine/edge/community --allow-untrusted --no-cache libcurl curl &> /dev/null
#########################################################################



#########################################################################
#                               Hardening Script                        #
#########################################################################
        group_check=$(cat /etc/group | grep -i docker | cut -d : -f 1)
        user_check=$(cat /etc/passwd | grep -i docker | cut -d : -f 1)
                if [[ "$group_check" == "docker" && "$user_check" == "dockeruser" ]]; then
                        echo "Non-root User,Group already added"
                else
## Create non-root user
                        USERNAME=dockeruser
                        USERID=9000
                        GROUP=docker
                        GID=9001
                        addgroup -g $GID -S $GROUP
                        adduser -D -u $USERID -G $GROUP -h /home/$USERNAME -s /bin/sh $USERNAME
                        sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow
                        echo "Non-root User,Group added"
                        # Remove interactive login shell for all except essential ones
                        sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd
                fi

## Assigning sudo permission to non-root user ##
## sudo utility check - install only if missing ##
## We are installing sudo in a pre-hardening stage##
#sudo --help &> /dev/null

 #       if [[ $? != 0 ]]; then
                #apk add --no-cache sudo &> /dev/null
 #               apk add --repository http://mirror.yandex.ru/mirrors/alpine/edge/community --allow-untrusted --no-cache sudo &> /dev/null
 #       fi
echo dockeruser ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/dockeruser || echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
chmod -R 0440 /etc/sudoers.d/$USERNAME

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

## Change the UID/GID of an existing container user ##
#groupmod --help &> /dev/null
#       if [[ $? != 0 ]]; then
#               apk add --no-cache shadow &> /dev/null
#       fi
#groupmod -g 9001 docker
#usermod --uid 9000 --gid 9001 dockeruser
#apk del --force --purge shadow  &> /dev/null

chown -R 9000:9001 /home/dockeruser || chown -R $USERID:$GID /home/$USERNAME

# Remove all from /passwd /shadow /group except essential ones
sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/passwd
sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/shadow
sed -i -r '/^('$GROUP'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/group


# Remove interactive login shell for all except essential ones
#sed -i -r '/^('$USERNAME'|root|nginx|kong|nobody|nogroup|sshd):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

# Avoid error `Only root may specify -c or -f` when using
# ForceCommand with `-f` option at non-root ssh login.
# https://www.duosecurity.com/docs/duounix-faq#can-i-use-login_duo-to-protect-non-root-shared-accounts,-or-can-i-do-an-install-without-root-privileges?
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

# Remove all but a handful of admin commands.
# Below cmd removes "apk|apt-get update". Run it only if absolutely necessary
#find /sbin /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete || find /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
        find / -xdev -type d -perm /0002 -exec chmod o-w {} + \
&&      find / -xdev -type f -perm /0002 -exec chmod o-w {} +

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
        find $sysdirs -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d             \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {} \;   ||     \
        find $sysdirs1 -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d            \
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

# To fix the warning "su: must be suid to work properly" in 'kong' with Alpine
chmod 4755 /bin/su

## remove private keys
#rm -f /usr/local/go/src/crypto/tls/testdata/example-key.pem
rm -rf /usr/local/go/src/crypto/tls/testdata/*.pem /usr/share/doc/python27-pygpgme-0.3/tests/keys/*.sec

# Remove 'sudo' pkg along with dependencies.
apk del --purge --rdepends --quiet sudo

## revert back to 'https' from 'http' for repos ##
## Using Host ca-certificates for the repos##
#a=`sed -ie s/https/http/g /etc/apk/repositories`
#if [[ "$a" != 0 ]]; then
#        sed -ie s/http/https/g /etc/apk/repositories
#fi

####################    Hardening Script Concludes      #########################
