#!/bin/sh
#
# Copyright 2014 Karl Denninger <karl at denninger.net>
# Cribbed modified from original as below
#
# Copyright (c) 2005 Pawel Jakub Dawidek <pjd at FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD$
#

# PROVIDE: disks
# REQUIRE: initrandom
# KEYWORD: nojail

. /etc/rc.subr

name="encrypt"
start_cmd="encrypt_start"
stop_cmd="encrypt_stop"
required_modules="geom_eli:g_eli"

encrypt_start()
{

     devices=${encrypt_disks}

     echo -n 'Geli attach Password: '
     stty -echo
     read password
     stty echo
     echo

         if [ -z "${encrypt_tries}" ]; then
                 if [ -n "${encrypt_attach_attempts}" ]; then
                         # Compatibility with rc.d/gbde.
                         encrypt_tries=${encrypt_attach_attempts}
                 else
                         encrypt_tries=`${SYSCTL_N} kern.geom.eli.tries`
                 fi
         fi

     for provider in ${devices}; do
         provider_=`ltr ${provider} '/-' '_'`

         eval "flags=\${encrypt_${provider_}_flags}"
         if [ -z "${flags}" ]; then
             flags=${encrypt_default_flags}
         fi
         if [ -e "/dev/${provider}" -a ! -e "/dev/${provider}.eli" ]; then
             echo "Geli attach ${provider}."
             count=1
             while [ ${count} -le ${encrypt_tries} ]; do
                 echo $password | geli attach -j - ${flags} ${provider}
                 if [ -e "/dev/${provider}.eli" ]; then
                     break
                 fi
                 echo "Attach failed; attempt ${count} of ${encrypt_tries}."
                 count=$((count+1))
                 if [ ${count} -gt ${encrypt_tries} ]; then
                     echo "KEY MISMATCH ERROR - Abort"
                     exit 1
                 fi
                 echo -n 'Geli attach Password: '
                 stty -echo
                 read password
                 stty echo
                 echo
             done
         else
             if [ -e "/dev/${provider}" ]; then
                 echo "${provider} is already attached."
             else
                 echo "${provider} does not exist."
             fi
         fi
     done

        zpool export zraid1
        zpool import zraid1
}

encrypt_stop()
{
     devices=${encrypt_disks}

     for provider in ${devices}; do
         if [ -e "/dev/${provider}.eli" ]; then
             umount "/dev/${provider}.eli" 2>/dev/null
             geli detach "${provider}"
         fi
     done
}

load_rc_config $name
run_rc_command "$1"
