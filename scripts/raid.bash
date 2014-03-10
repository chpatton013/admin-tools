#!/usr/bin/env bash

set -e

raid_device=/dev/md127
luks_device=storage
randomize=''
dryrun=''

###
 # Available commands.
 #    start
 #    stop
 #    mount
 #    unmount
 #    add_disk $disk
 #    remove_disk $disk
 #    add_bitmap
 #    remove_bitmap
 #    resize_raid $num_drives
 #    resize_luks
 #    resize_volume
 #
 #
 # Customization. Set any of the above variables to suit your needs.
 #    raid_device:   The path to the raid device after being started.
 #    luks_device:   The name given to the luks device after being opened.
 #    randomize:     Randomize new drives before adding? '' or 'true'
 #    dryrun:        Should commands actually be run? '' or 'true'
 #
 #
 # Sample usage.
 #
 # Start and mount the array:
 #    raid.bash start
 #    raid.bash mount
 #
 # Dismount and stop the array:
 #    raid.bash unmount
 #    raid.bash stop
 #
 # Add a disk to the array:
 #    raid.bash start
 #    raid.bash mount
 #    raid.bash add_disk /dev/sdX
 #
 # Remove a disk from the array:
 #    raid.bash start
 #    raid.bash mount
 #    raid.bash remove_disk /dev/sdX
 #
 # Grow the size of the array:
 #    raid.bash start
 #    raid.bash mount
 #    raid.bash add_disk /dev/sdX
 #    raid.bash remove_bitmap
 #    raid.bash resize_raid
 #    < wait until resizing has finished >
 #    raid.bash add_bitmap
 #    raid.bash resize_luks
 #    raid.bash resize_volume
 ##

function _perform() {
   echo "$@"

   if [ ! "$dryrun" ]; then
      $@
   fi
}

function _verify() {
   local message="$1"

   read -p "$message Are you sure you want to continue? " yn
   case "$yn" in
   [Yy]*)
      return;;
   *)
      echo "exiting..."
      exit 1;;
   esac
}

function _start() {
   local raid_device="$1"
   if [ ! "$raid_device" ]; then
      raid_device='--scan'
   fi

   _perform mdadm --assemble "$raid_device"
}

function _stop() {
   local raid_device="$1"
   if [ ! "$raid_device" ]; then
      echo "'stop' requires 'raid_device' to be specified"
      exit 1
   fi

   _perform mdadm --stop "$raid_device"
}

function _mount() {
   local raid_device="$1"
   local luks_device="$2"
   if [ ! "$raid_device" ] || [ ! "$luks_device" ]; then
      echo "'mount' requires 'raid_device' and 'luks_device' to be specified"
      exit 1
   fi

   _perform cryptsetup luksOpen "$raid_device" "$luks_device"
   _perform mkdir -p "/mnt/$luks_device"
   _perform mount "/dev/mapper/$luks_device" "/mnt/$luks_device"
}

function _unmount() {
   local luks_device="$1"
   if [ ! "$luks_device" ]; then
      echo "'unmount' requires 'luks_device' to be specified"
      exit 1
   fi

   _perform umount "/dev/mapper/$luks_device"
   _perform rmdir "/mnt/$luks_device"
   _perform cryptsetup luksClose "$luks_device"
}

function _prepare_disk() {
   local disk="$1"
   if [ ! "$disk" ]; then
      echo "'prepare_disk' requires 'disk' to be specified"
      exit 1
   fi

   if [ "$randomize" ]; then
      _perform dd if=/dev/urandom of="$disk" bs=8M
   fi

   local parted="parted --script --align optimal -- $disk"

   _perform "$parted" mklabel gpt
   _perform "$parted" mkpart primary 1 -0
}

function _add_disk() {
   local raid_device="$1"
   local disk="$2"
   if [ ! "$raid_device" ] || [ ! "$disk" ]; then
      echo "'_add_disk' requires 'raid_device' and 'disk' to be specified"
      exit 1
   fi

   _perform mdadm --manage "$raid_device" --add "$disk"1
}

function _remove_disk() {
   local raid_device="$1"
   local disk="$2"

   if [ ! "$raid_device" ] || [ ! "$disk" ]; then
      echo "'_add_disk' requires 'raid_device' and 'disk' to be specified"
      exit 1
   fi

   _perform mdadm --manage "$raid_device" --fail "$disk"1
   _perform mdadm --manage "$raid_device" --remove "$disk"1
}

function _add_bitmap() {
   local raid_device="$1"
   if [ ! "$raid_device" ]; then
      echo "'_add_bitmap' requires 'raid_device' to be specified"
      exit 1
   fi

   _perform mdadm --grow "$raid_device" --backup-file=./mdadm-backup-add-bmp --bitmap=internal
}

function _remove_bitmap() {
   local raid_device="$1"
   if [ ! "$raid_device" ]; then
      echo "'_remove_bitmap' requires 'raid_device' to be specified"
      exit 1
   fi

   _perform mdadm --grow "$raid_device" --backup-file=./mdadm-backup-remove-bmp --bitmap=none
}

function _resize_raid() {
   local raid_device="$1"
   local num_drives="$2"
   if [ ! "$raid_device" ] || [ ! "$num_drives" ]; then
      echo "'_resize_raid' requires 'raid_device' and 'num_drives' to be specified"
      exit 1
   fi

   _perform mdadm --grow "$raid_device" --backup-file=./mdadm-backup-add-devices --raid-devices="$num_drives"
}

function _resize_luks() {
   local raid_device="$1"
   local luks_device="$2"
   if [ ! "$raid_device" ] || [ ! "$luks_device" ]; then
      echo "'_resize_luks' requires 'raid_device' and 'luks_device' to be specified"
      exit 1
   fi

   _perform cryptsetup luksOpen "$raid_device" "$luks_device"
   _perform cryptsetup resize "$luks_device"
}

function _resize_volume() {
   local luks_device="$1"
   if [ ! "$luks_device" ]; then
      echo "'_resize_volume' requires 'luks_device' to be specified"
      exit 1
   fi

   _perform resize2fs "/dev/mapper/$luks_device"
}

command="$1"
case "$command" in
'start')
   _start
   ;;
'stop')
   _stop "$raid_device"
   ;;
'mount')
   _mount "$raid_device" "$luks_device" "/mnt/$luks_device"
   ;;
'unmount')
   _unmount "$luks_device" "/mnt/$luks_device"
   ;;
'add_disk')
   disk="$2"
   if [ ! "$disk" ]; then
      echo "'add_disk' requires 'disk' to be specified"
      exit 1
   fi
   _verify "Adding disk '$disk' to raid device '$raid_device'."
   _prepare_disk "$disk"
   _add_disk "$raid_device" "$disk"
   ;;
'remove_disk')
   disk="$2"
   if [ ! "$disk" ]; then
      echo "'remove_disk' requires 'disk' to be specified"
      exit 1
   fi
   _verify "Removing disk '$disk' from raid device '$raid_device'."
   _remove_disk "$raid_device" "$disk"
   ;;
'add_bitmap')
   _verify "Adding internal bitmap to raid device '$raid_device'."
   _add_bitmap "$raid_device"
   ;;
'remove_bitmap')
   _verify "Removing internal bitmap from raid device '$raid_device'."
   _remove_bitmap "$raid_device"
   ;;
'resize_raid')
   num_drives="$2"
   if [ ! "$num_drives" ]; then
      echo "'grow' requires 'num_drives' to be specified"
      exit 1
   fi
   _verify "Resizing raid device '$raid_device' with $num_drives drives."
   _resize_raid "$raid_device" "$num_drives"
   ;;
'resize_luks')
   _verify "Resizing luks device '$luks_device' on raid device '$raid_device'."
   _grow_luks "$raid_device" "$luks_device"
   ;;
'resize_volume')
   _verify "Resizing filesystem on luks device '$luks_device'."
   _resize_volume "$luks_device"
   ;;
*)
   echo "Unrecognized command: $command"
   exit 1
   ;;
esac

