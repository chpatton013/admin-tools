#!/usr/bin/env sh

source script-vars.sh

umount /dev/mapper/$LUKS_DEVICE
rmdir $MOUNT_POINT
cryptsetup luksClose $LUKS_DEVICE
