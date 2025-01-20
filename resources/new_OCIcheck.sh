#!/bin/bash

#set -x

Image=$1

BASH_VAR=$( { docker run --rm -a stdout --entrypoint cat $Image /etc/os-release; } 2>&1 )
a=`echo $BASH_VAR | tr [:upper:] [:lower:] | grep -o "oci runtime create failed" | cut -f4 -d : | tr -d " "`
b=ociruntimecreatefailed
        if [[ "$a" == "$b" ]]; then
                echo "'$Image' image runtime failed. Hardening stage skipped as '$Image' cannot be Hardened."
        else
                echo "success"
        fi
