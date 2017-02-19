#!/bin/bash
# 
# Copyright (c) 2015-2017, Gregory M. Kurtzer. All rights reserved.
# 
# Copyright (c) 2016-2017, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
# 
# This software is licensed under a customized 3-clause BSD license.  Please
# consult LICENSE file distributed with the sources of this project regarding
# your rights to use or distribute this software.
# 
# NOTICE.  This Software was developed under funding from the U.S. Department of
# Energy and the U.S. Government consequently retains certain rights. As such,
# the U.S. Government has been granted for itself and others acting on its
# behalf a paid-up, nonexclusive, irrevocable, worldwide license in the Software
# to reproduce, distribute copies to the public, prepare derivative works, and
# perform publicly and display publicly, and to permit other to do so. 
# 
# 

## Basic sanity
if [ -z "$SINGULARITY_libexecdir" ]; then
    echo "Could not identify the Singularity libexecdir."
    exit 1
fi

## Load functions
if [ -f "$SINGULARITY_libexecdir/singularity/functions" ]; then
    . "$SINGULARITY_libexecdir/singularity/functions"
else
    echo "Error loading functions: $SINGULARITY_libexecdir/singularity/functions"
    exit 1
fi

if [ -z "${SINGULARITY_ROOTFS:-}" ]; then
    message ERROR "Singularity root file system not defined\n"
    exit 1
fi


install -d -m 0755 "$SINGULARITY_ROOTFS/.singularity"
install -d -m 0755 "$SINGULARITY_ROOTFS/.singularity/env"
install -d -m 0755 "$SINGULARITY_ROOTFS/.singularity/labels"
install -d -m 0755 "$SINGULARITY_ROOTFS/.singularity/actions"
install -d -m 0755 "$SINGULARITY_ROOTFS/bin"
install -d -m 0755 "$SINGULARITY_ROOTFS/dev"
install -d -m 0755 "$SINGULARITY_ROOTFS/home"
install -d -m 0755 "$SINGULARITY_ROOTFS/etc"
install -d -m 0750 "$SINGULARITY_ROOTFS/root"
install -d -m 0755 "$SINGULARITY_ROOTFS/proc"
install -d -m 0755 "$SINGULARITY_ROOTFS/sys"
install -d -m 1777 "$SINGULARITY_ROOTFS/tmp"
install -d -m 1777 "$SINGULARITY_ROOTFS/var/tmp"

touch "$SINGULARITY_ROOTFS/etc/hosts"
touch "$SINGULARITY_ROOTFS/etc/resolv.conf"

test -L "$SINGULARITY_ROOTFS/etc/mtab"  && rm -f "$SINGULARITY_ROOTFS/etc/mtab"

cat > "$SINGULARITY_ROOTFS/etc/mtab" << EOF
singularity / rootfs rw 0 0
EOF



if [ -x "$SINGULARITY_ROOTFS/bin/bash" ]; then
    HELPER_SHELL="/bin/bash"
else
    HELPER_SHELL="/bin/sh"
fi

cat > "$SINGULARITY_ROOTFS/.singularity/env/01-base.sh" << EOF

if test -z "\$SINGULARITY_INIT"; then
    PATH=\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
    PS1="Singularity.\$SINGULARITY_CONTAINER> "
    SINGULARITY_INIT=1
    export PATH PS1 SINGULARITY_INIT
fi
EOF
chmod 0644 "$SINGULARITY_ROOTFS/.singularity/env/01-base.sh"


cat > "$SINGULARITY_ROOTFS/.singularity/actions/shell" << EOF
#!$HELPER_SHELL

for script in /.singularity/env/*.sh; do
    if [ -f "\$script" ]; then
        . \$script
    fi
done

if test -n "$\SHELL" -a -x "\$SHELL"; then
    exec "\$SHELL" "\$@"
else
    echo "ERROR: Shell does not exist in container: \$SHELL" 1>&2
    echo "ERROR: Using /bin/sh instead..." 1>&2
fi
if test -x /bin/sh; then
    SHELL=/bin/sh
    export SHELL
    exec /bin/sh "\$@"
else
    echo "ERROR: /bin/sh does not exist in container" 1>&2
fi
exit 1
EOF
chmod 0755 "$SINGULARITY_ROOTFS/.singularity/actions/shell"



cat > "$SINGULARITY_ROOTFS/.singularity/actions/exec" << EOF
#!$HELPER_SHELL

for script in /.singularity/env/*.sh; do
    if [ -f "\$script" ]; then
        . \$script
    fi
done
exec "\$@"
EOF
chmod 0755 "$SINGULARITY_ROOTFS/.singularity/actions/exec"



cat > "$SINGULARITY_ROOTFS/.singularity/actions/run" << EOF
#!$HELPER_SHELL

for script in /.singularity/env/*.sh; do
    if [ -f "\$script" ]; then
        . \$script
    fi
done

if test -x /.singularity/runscript; then
    exec /.singularity/runscript "\$@"
else
    echo "No Singularity runscript found, executing /bin/sh"
    exec /bin/sh "\$@"
fi
EOF
chmod 0755 "$SINGULARITY_ROOTFS/.singularity/actions/run"

