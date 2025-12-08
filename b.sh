#!/bin/bash
set -euo pipefail

# prerequsites: just make sure you connected the special usb. rest is handled.

# step 1: mount usb if not already mounted
# check if mounted
if ! mountpoint -q "/mnt/usb/"; then
    echo "no usb is mounted at /mnt/usb/"

    # prompt for drive letter , e.g. d (sdd1) or e (sde1)
    read -p "enter letter [x] to mount sd[x]1: " letter
    if [[ "$letter" =~ ^[a-z]$ ]]; then # check if one letter
        sudo mount /dev/sd${letter}1 /mnt/usb/
        # make sure mount succeeded
        if ! mountpoint -q "/mnt/usb/"; then
            echo "ERROR: Failed to mount /dev/sd${letter}1"
            exit 1
        fi
    else
        echo "invalid input"
        exit 1
    fi
fi

# check if /mnt/usb/backup/btrfs_snapshots/ exists
if [[ ! -d "/mnt/usb/backup/btrfs_snapshots/" ]]; then
    echo "could not find folder backup/btrfs_snapshots/ in mount point /mnt/usb/"
    exit 1
fi

# step 2: mount btrfs root if not already mounted
# check if /dev/sda3 is mounted
root="/mnt/root-btrfs"
if ! mountpoint -q "$root"; then
    echo "btrfs root is not mounted. mounting at /mnt/root-btrfs/ ..."
    sudo mount "/dev/sda3" "$root"
fi

# check if partitions @ and @home exist , and check if snapshots/ exists
cd "$root"
if [[ ! -d "@/" || ! -d "@home/" || ! -d "snapshots/" ]]; then
    echo "missing either @/ , @home/ , or snapshots/ in /mnt/root-btrfs/"
    exit 1
fi

# step 3: create snapshots
SUFFIX="$(date +%Y-%m-%d_%H%M)"
echo "creating snapshots ..."
sudo btrfs subvolume snapshot -r "@/" "snapshots/@_$SUFFIX"
sudo btrfs subvolume snapshot -r "@home/" "snapshots/@home_$SUFFIX"

# step 4: backup snapshots
echo
echo "backing up @ snapshot (this may take a while) ..."
sudo btrfs send "snapshots/@_$SUFFIX" | zstd > "/mnt/usb/backup/btrfs_snapshots/potato/@_$SUFFIX.btrfs.zst"

echo
echo "backing up @home snapshot (this may take a while) ..."
sudo btrfs send "snapshots/@home_$SUFFIX" | zstd > "/mnt/usb/backup/btrfs_snapshots/potato/@home_$SUFFIX.btrfs.zst"

echo "backup completed successfully: $SUFFIX"

# step 5: final message
echo
echo "make sure to delete the created snapshots in $root if you don't want to keep them there! you can now run pacman -Syu to upgrade."
