#!/usr/bin/env sh

. ./script-vars.sh

umount /dev/mapper/$LUKS_DEVICE
rmdir $MOUNT_POINT
cryptsetup luksClose $LUKS_DEVICE
