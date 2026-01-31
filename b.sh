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
            echo "[ERROR] failed to mount /dev/sd${letter}1"
            exit 1
        fi
    else
        echo "[ERROR] invalid input"
        exit 1
    fi
else
    echo "[GOOD] found usb in /mnt/usb/"
fi

# check if /mnt/usb/backup/btrfs_snapshots/ exists
if [[ ! -d "/mnt/usb/backup/btrfs_snapshots/" ]]; then
    echo "[ERROR] could not find folder backup/btrfs_snapshots/ in mount point /mnt/usb/"
    exit 1
else
    echo "[GOOD] found backup folder in /mnt/usb/backup/btrfs_snapshots/"
fi

# step 2: mount btrfs root if not already mounted
root="/dev/nvme0n1p3"
root_mount="/mnt/root-btrfs"
if ! mountpoint -q "$root_mount"; then
    echo "btrfs root is not mounted at $root_mount"
    read -p "confirm if the root is located at $root (Y/n): " response
    response=${response:-Y}

    # prompt user for path to root filesystem
    if [[ $response =~ ^[Nn]$ ]]; then
        read -p "enter path to btrfs root: " root
        if [[ ! -b $root ]]; then
            echo "[ERROR] not a valid block device: $root"
            exit 1
        fi
    elif [[ ! $response =~ ^[Yy]$ ]]; then
        echo "[ERROR] invalid input. operation cancelled."
        exit 1
    fi

    # mount now
    sudo mkdir -p "$root_mount"
    sudo mount "$root" "$root_mount"
    echo "[GOOD] mounted $root at $root_mount"
else
    echo "[GOOD] already mounted at $root_mount"
fi

# check if partitions @ and @home exist , and check if snapshots/ exists
cd "$root_mount"
if [[ ! -d "@/" || ! -d "@home/" || ! -d "snapshots/" ]]; then
    echo "[ERROR] missing either @/ , @home/ , or snapshots/ in $root_mount"
    exit 1
else
    echo "[GOOD] found partitions @ and @home in $root_mount"
fi

# step 3: create snapshots
SUFFIX="$(date +%Y-%m-%d_%H%M)"
echo "[CREATING SNAPSHOTS]"
sudo btrfs subvolume snapshot -r "@/" "snapshots/@_$SUFFIX"
sudo btrfs subvolume snapshot -r "@home/" "snapshots/@home_$SUFFIX"

# step 4: backup snapshots
echo
echo "[BACKING UP SNAPSHOTS]"

echo "backing up @ snapshot (this may take a while) ..."
sudo btrfs send "snapshots/@_$SUFFIX" | pv | zstd > "/mnt/usb/backup/btrfs_snapshots/potato/@_$SUFFIX.btrfs.zst"

echo "backing up @home snapshot (this may take a while) ..."
sudo btrfs send "snapshots/@home_$SUFFIX" | pv | zstd > "/mnt/usb/backup/btrfs_snapshots/potato/@home_$SUFFIX.btrfs.zst"

echo "[GOOD] backup completed successfully: $SUFFIX"

# step 5: final message
echo
echo "make sure to delete the created snapshots in $root_mount if you don't want to keep them there! you can now run pacman -Syu to upgrade."
