#!/usr/bin/env sh

. ./script-vars.sh

DISK=$1
PARTED="parted --align optimal --script $DISK"

$PARTED mklabel gpt
$PARTED mkpart primary 1 -0

mdadm --add $RAID_DEVICE "$DISK"1
# TODO: finish this
