#!/bin/bash

# Add repo
        zypper rr --all &> /dev/null \
        && zypper clean --all &> /dev/null \
        && zypper addrepo  http://download.opensuse.org/distribution/leap/15.6/repo/oss/ oss &> /dev/null \
        && zypper --quiet --non-interactive --gpg-auto-import-keys ref &> /dev/null

        #zypper repos || mn=1 && zypper -q refresh || mn=1 && zypper list-updates && zypper -nq update && zypper -q patch-check && zypper -q list-patches && zypper -nq patch
#zypper addrepo http://download.opensuse.org/update/leap/15.3/oss/ oss


#########################################################################
#                       Remediate vulnerable pkgs                       #
#########################################################################


#########################################################################


#########################################################################
#                       Hardening Script                                #
#########################################################################
        group_check=$(cat /etc/group | grep -i docker | cut -d : -f 1)
        user_check=$(cat /etc/passwd | grep -i docker | cut -d : -f 1)
                if [[ $group_check == docker && $user_check == dockeruser ]]; then
                        echo "Non-root User,Group already added"
                else
## Create non-root user
#zypper install -y shadow sed findutils
                        USERNAME=dockeruser
                        USERID=9000
                        GROUP=docker
                        GID=9001

                        groupadd --help &> /dev/null
                                if [[ $? != 0 ]]; then
                                        zypper -q install -y --no-recommends shadow &> /dev/null
                                fi
                        sed --help &> /dev/null
                                if [[ $? != 0 ]]; then
                                        zypper -q install -y --no-recommends  sed &> /dev/null
                                fi

                        groupadd -g $GID $GROUP                                                         \
                &&      sed -i 's/^CREATE_MAIL_SPOOL=yes/CREATE_MAIL_SPOOL=no/' /etc/default/useradd    \
                &&      useradd -u $USERID -g $GROUP -m -s /bin/sh $USERNAME                            \
                &&      echo "Non-root User,Group added"                                                \
                &&      sed -i 's/^CREATE_MAIL_SPOOL=no/CREATE_MAIL_SPOOL=yes/' /etc/default/useradd    
                # &&      sed -i -r 's/^'$USERNAME':!:/'$USERNAME':x:/' /etc/shadow
                # Check if OpenSSL is present in the image
                        if ! command -v openssl &> /dev/null; then
                                echo "openssl is not intalled."
                                openssl_installed=false
                                zypper -q install -y --no-recommends openssl &> /dev/null
                        fi

                # Set a hashed password for the user
                # Prompt for a password (this can be changed to take an environment variable if needed)
                        PASSWORD="dockeruser"  # Or obtain this from an ENV variable
                        echo "$USERNAME:$(openssl passwd -6 "$PASSWORD")" >> /etc/shadow
                # Update UMASK in /etc/login.defs
                        sed -i 's/^UMASK\s\+[0-9]\{3\}/UMASK 077/' /etc/login.defs

                # Enable SHA_CRYPT_ROUNDS
                        sed -i 's/^#\s*SHA_CRYPT_MIN_ROUNDS/SHA_CRYPT_MIN_ROUNDS/' /etc/login.defs
                        sed -i 's/^#\s*SHA_CRYPT_MAX_ROUNDS/SHA_CRYPT_MAX_ROUNDS/' /etc/login.defs
        
                # Remove interactive login shell for all except essential ones
                        sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd
                fi

## Assigning sudo permission to non-root user ##
## sudo utility check - install only if missing ##
sudo --help &> /dev/null
        if [[ $? != 0 ]]; then
                zypper -q install -y --no-recommends sudo &> /dev/null
        fi
echo dockeruser ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/dockeruser || echo $USERNAME ALL=\(root\) PASSWD:ALL > /etc/sudoers.d/$USERNAME
chmod -R 0440 /etc/sudoers.d/$USERNAME

## Assign new password for Root

#password=$(awk '{print $1;}' secret.txt)
#password=$(cat secret.txt)
password=$(cat /run/secrets/rt_psw)
echo -e "$password\n$password\n" | passwd root
        if [[ $? != 0 ]]; then
                exit 1
        fi
        echo "Defaults    rootpw" >> /etc/sudoers
        echo "Defaults        env_reset,timestamp_timeout=0" >> /etc/sudoers

# Change the UID/GID of an existing container user
        groupmod -g 9001 docker                                 \
&&      usermod --uid 9000 --gid 9001 dockeruser &> /dev/null   \
&&      chown -R 9000:9001 /home/dockeruser || chown -R $USERID:$GID /home/$USERNAME

# Remove all from /passwd /shadow /group except essential ones
        sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/passwd         \
&&      sed -i -r '/^('$USERNAME'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/shadow         \
&&      sed -i -r '/^('$GROUP'|root|rabbitmq|_apt|postmaster|postgres|sshd|rabbitmq|kong|nginx|nobody|operator|guest|bin|ping|wheel|man|adm|daemon|ftp|mail|sudo|kibana|irc|sys|gnats|proxy|list|www-data|users|systemd-network|dbus|lp|tty|systemd-journal|node|smmsp|ntp|vpopmail|xfs|squid|uucp|shadow|nofiles|nogroup|xfs|kvm|elasticsearch|flink)/!d' /etc/group

## Remove interactive login shell for all except essential ones
#sed -i -r '/^('$USERNAME'|root|sshd|kong|nogroup|nginx|nobody):/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

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
  awk --help &> /dev/null
    if [[ $? == 0 ]]; then
        zypper -q install -y --no-recommends gawk &> /dev/null
        awk '$5 >= 2000' ${moduli}.orig > ${moduli}
        zypper -q rm -y gawk &> /dev/null
    fi
  rm -f ${moduli}.orig
fi

# Remove existing crontabs, if any.
        rm -fr /var/spool/cron  \
&&      rm -fr /etc/crontabs    \
&&      rm -fr /etc/periodic

find --help &> /dev/null
        if [[ $? != 0 ]]; then
                zypper -q install -y --no-recommends  findutils &> /dev/null
        fi


# Remove all but a handful of admin commands.
# Below cmd deletes content of "/usr/sbin". Run it only if absolutely necessary
#find /sbin /usr/sbin ! -type d -a ! -name login_duo -a ! -name nologin -a ! -name setup-proxy -a ! -name sshd -a ! -name start.sh -delete

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
        find $sysdirs -xdev -regex '.*apk.*' -exec rm -fr {} + \
||      find $sysdirs1 -xdev -regex '.*apt.*' -exec rm -fr {} +

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
        find $sysdirs -xdev -type f -regex '.*-$' -exec rm -f {} + \
||      find $sysdirs1 -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
        find /lib /lib64 /usr/lib /usr/lib64 -perm /022 -type f -exec chmod 755 '{}' \;
        find $sysdirs -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d             \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {} \;   ||     \
        find $sysdirs1 -xdev \( -path "*/elasticsearch" -o -path "*/nginx" \) -prune -o -type d            \
                -exec chown root:root {} \;     \
                -exec chmod 0755 {}      \;

# Remove all suid files.
# Below cmd disables switch user. Run it only if absolutely necessary
        #find $sysdirs -xdev -type f -a -perm /4000 -delete || find $sysdirs1 -xdev -type f -a -perm /4000 -delete

# Remove following utilities that could be prone to new vulnerabilities.
        #find $sysdirs -xdev \( -name hexdump -o  -name chgrp -o -name chmod -o -name chown -o -name ln -o -name od -o -name strings -o -name su \)  -exec rm -fr {} + || find $sysdirs1 -xdev \( -name hexdump -o  -name chgrp -o -name chmod -o -name chown -o -name ln -o -name od -o -name strings -o -name su \) -exec rm -fr {} +        
        #find $sysdirs -xdev \( -name hexdump -o  -name chgrp -o  -name ln -o -name od -o -name mn=1 \)  -exec rm -fr {} + || \
        #find $sysdirs1 -xdev \( -name hexdump -o  -name chgrp -o  -name ln -o -name od -o -name mn=1 \) -exec rm -fr {} +
        find $sysdirs -xdev \( -name hexdump -o  -name ln -o -name od -o -name mn=1 \)  -exec rm -fr {} + || \
        find $sysdirs1 -xdev \( -name hexdump -o -name ln -o -name od -o -name mn=1 \) -exec rm -fr {} +
        #find $sysdirs $sisdirs1 ! -group root -type f -exec chgrp root '{}' \;

# Remove init scripts since we do not use them.
#rm -fr /etc/init.drm -fr /lib/rc \
#rm -fr /etc/conf.d \
#rm -fr /etc/inittab \
#rm -fr /etc/runlevels \
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

# remove 'sudo' along with dependencies
zypper -q rm -yu sudo &> /dev/null

# Remove broken symlinks (because we removed the targets above).
        find $sysdirs -xdev -type l -exec test ! -e {} \; -delete \
||      find $sysdirs1 -xdev -type l -exec test ! -e {} \; -delete


#zypper -q rm -y libaudit1 libsemanage1 pam sed sed-lang shadow which findutils &> /dev/null
#zypper -q rm -y   sed   findutils &> /dev/null
#Remove OpenSSL if it was not present in the base image
if [ "$openssl_installed" = false ]; then
        echo "Uninstalling OpenSSL..."
        zypper remove -y openssl
fi

zypper rr --all &> /dev/null && zypper clean --all &> /dev/null


## remove private keys
#rm -f /usr/local/go/src/crypto/tls/testdata/example-key.pem
rm -rf /usr/local/go/src/crypto/tls/testdata/*.pem /usr/share/doc/python27-pygpgme-0.3/tests/keys/*.sec 
#/usr/lib/utempter

############################################################################################################
