# help

this place stores zipped btrfs stream files

## what are btrfs stream files

btrfs stream files are when you take a read only btrfs snapshot and use `btrfs
send` to store it somewhere. it is essentially a binary that btrfs can restore
using `btrfs receive`.

## zipper

for zipping the stream files , we are using `zstd`

## usage

### b.sh

the script `b.sh` does all the steps in `making a snapshot` , `backing up` and
`backing up /boot`. read those sections to get a closer look.

all you need to do for `b.sh` to work is just plug in the special usb. the
mounting is all handled , but if you already have something mounted that is also
fine.

also make sure to delete older snapshots on the pc if you don't need them anymore.

### making a snapshot

to make a btrfs snapshot ,

```sh
# first mount the root of the btrfs filesystem
sudo mount /dev/sda3 /mnt/root-btrfs
cd /mnt/root-btrfs

# make a readonly snapshot of either @ or @home
sudo btrfs subvolume snapshot -r \@home/ snapshots/\@home_$(date +%Y-%m-%d_%H%M)
```

note that there should exist a `snapshots/` folder in the btrfs root. if not ,
then make one.

### backing up

to backup a snapshot named `@home_date` ,

```sh
cd /mnt/root-btrfs/snapshots

# set to read only
sudo btrfs property set -ts \@home_date ro true

# backup
SNAP=\@home_date
sudo btrfs send $SNAP | zstd > /mnt/usb/backup/btrfs_snapshots/potato/$SNAP.btrfs.zst
```

### backing up /boot

`/boot` is a separate fat partition (the efi partition) , so it is not part of
the `@` snapshot. it holds the kernel , initramfs and bootloader , so it must
match the kernel modules in `@` (`/usr/lib/modules`). back it up together with
the `@` snapshot , using the same date ,

```sh
sudo tar -cf - -C /boot . | zstd > /mnt/usb/backup/btrfs_snapshots/potato/boot_date.tar.zst
```

### restoring

to restore a compressed btrfs stream file named `@home_date.btrfs.zst` ,

```sh
cd /mnt/root-btrfs/snapshots
zstd -dc /mnt/usb/backup/btrfs_snapshots/potato/\@home_date.btrfs.zst | sudo btrfs receive .
```

if you want to set the restored snapshot as the subvolume in use:

```sh
cd /mnt/root-btrfs

# backup old subvolume
sudo mv \@home snapshots/\@home_$(date +%y-%m-%d_%H%M)

# set snapshot as main subvolume
sudo btrfs subvolume snapshot snapshots/\@home_date \@home
```

the above methond preserves both the old subvolume that was in use and frozen
snapshot of `@home_date`. just reboot your system now and pray it didn't break
somehow.

### restoring /boot

if you restored `@` , also restore `/boot` from the same date. otherwise the
kernel in `/boot` may not match the modules in the restored `@` and the system
may not boot.

```sh
# backup current /boot contents first
sudo tar -cf - -C /boot . | zstd > ~/boot_old_$(date +%Y-%m-%d_%H%M).tar.zst

# restore (fat has no unix owners or permissions , so don't try to keep them)
zstd -dc /mnt/usb/backup/btrfs_snapshots/potato/boot_date.tar.zst | sudo tar -xf - -C /boot --no-same-owner --no-same-permissions
```

if restoring from a live usb , mount the efi partition first (e.g. `sudo mount
/dev/nvme0n1p1 /mnt/boot`) and use that path instead of `/boot`. the old
`/boot` backup also has to be saved somewhere outside the system , not `~`.

### inspecting btrfs subvolume

to see all existing subvolumes and how much space they are taking , you can do ,

```sh
sudo btrfs qgroup show /
```
