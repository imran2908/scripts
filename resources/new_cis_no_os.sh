#!/bin/sh

## non-root user check ##
        group_check=$(cat /etc/group | grep -i docker | cut -d : -f 1)
        user_check=$(cat /etc/passwd | grep -i docker | cut -d : -f 1)
                if [[ "$group_check" == "docker" && "$user_check" == "dockeruser" ]]; then
                        echo "Non-root User,Group already exist"
                else
## Create non-root user
                        USERNAME=dockeruser
                        USERID=9000
                        GROUP=docker
                        GID=9001
                        addgroup --help &> /dev/null
                        if [[ $? == 0 ]]; then
                                addgroup -g $GID -S $GROUP
                                adduser -D -u $USERID -G $GROUP -h /home/$USERNAME -s /bin/sh $USERNAME
                                echo "Non-root User,Group newly added"
                        else
                                groupadd -g $GID $GROUP
                                useradd -u $USERID -g $GROUP -m -s /bin/sh $USERNAME
                                echo "Non-root User,Group newly added"
                        fi                                                
# Remove interactive login shell for all except essential ones
                        #sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow
                        sed -i -r '/^('"$USERNAME"'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd
                fi
        #echo -n "" > /etc/sudoers.d
#       echo dockeruser ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/dockeruser || echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
#       chmod 0440 /etc/sudoers.d/$USERNAME

## Assigning sudo permission to non-root user ##
## sudo utility check - install only if missing ##
sudo --help &> /dev/null
        if [[ $? != 0 ]]; then
                #yum update -y &> /dev/null; 
                yum install -y sudo &> /dev/null
        fi
echo dockeruser ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/dockeruser || echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
chmod -R 0440 /etc/sudoers.d/$USERNAME


## Reset root password ##
#password=$(awk '{print $1;}' secret.txt)
##password=$(cat secret.txt)
##passwd --help &> /dev/null
password=$(cat /run/secrets/rt_psw)
echo -e "$password\n$password\n" | passwd root
        if [[ $? != 0 ]]; then
                yum install -y passwd &> /dev/null
                echo -e "$password\n$password\n" | passwd root 
                        if [[ $? != 0 ]]; then
                                exit 1
                        fi
                yum erase -y passwd &> /dev/null
        else
                echo -e "$password\n$password\n" | passwd root
                        if [[ $? != 0 ]]; then
                                exit 1
                        fi
        fi
        echo "Defaults    rootpw" > /etc/sudoers
        echo "Defaults        env_reset,timestamp_timeout=0" >> /etc/sudoers

# Change the UID/GID of an existing container user
#groupmod -g 9001 docker
#usermod --uid 9000 --gid 9001 dockeruser
#chown -R 9000:9001 /home/dockeruser || chown -R $USERID:$GID /home/$USERNAME


# Remove all from /etc/shadow /etc/group except essential ones

sed -i -r '/^(dockeruser|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/shadow;
sed -i -r '/^('$GROUP'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/group

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

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
##        find / -xdev -type d -perm /0002 -exec chmod o-w {} + \
##&&      find / -xdev -type f -perm /0002 -exec chmod o-w {} +

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

# Remove crufty...
        find $sysdirs -xdev -type f -regex '.*-$' -exec rm -f {} + \
||      find $sysdirs1 -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
        find $sysdirs -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d             \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {} \;   ||     \
        find $sysdirs1 -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d            \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {}     \;

# Remove other programs that could be dangerous.
        find $sysdirs -xdev \( -name hexdump -o -name ln -o -name od -o -name mn=1 \)  -exec rm -fr {} + || \
        find $sysdirs1 -xdev \( -name hexdump -o -name ln -o -name od -o -name mn=1 \) -exec rm -fr {} +

# Remove broken symlinks (because we removed the targets above).
        find $sysdirs -xdev -type l -exec test ! -e {} \; -delete \
||      find $sysdirs1 -xdev -type l -exec test ! -e {} \; -delete

# To fix the warning "su: must be suid to work properly" in 'kong' with Alpine
#chmod 4755 /bin/su

## remove private keys
#rm -f /usr/local/go/src/crypto/tls/testdata/example-key.pem
rm -rf /usr/local/go/src/crypto/tls/testdata/*.pem /usr/share/doc/python27-pygpgme-0.3/tests/keys/*.sec

####################    Hardening Script Concludes      #########################
