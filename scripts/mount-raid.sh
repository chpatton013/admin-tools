#!/usr/bin/env sh

source script-vars.sh

cryptsetup luksOpen $RAID_DEVICE $LUKS_DEVICE
mkdir -p $MOUNT_POINT
mount /dev/mapper/$LUKS_DEVICE $MOUNT_POINT
