#!/bin/bash
# ================================================
# LUKS Disk Encryption, Mount & Symlink Script
# ================================================
# This script will:
# 1. Ensure required tools are installed
# 2. Format a partition with LUKS
# 3. Open the LUKS container
# 4. Create a filesystem inside
# 5. Mount the encrypted partition
# 6. Create a symlink in home directory
# 7. (Optional) Configure automatic unlocking at boot
# ================================================

# -----------------------------
# 1. Check partition and system
# -----------------------------
echo "Listing all block devices and filesystems:"
lsblk -f
echo
echo "Checking disk usage for data mounts:"
df -h
echo

# -----------------------------
# 2. Install cryptsetup if needed
# -----------------------------
echo "Updating package index and installing cryptsetup..."
sudo apt update
sudo apt install -y cryptsetup

# -----------------------------
# 3. Unmount the target partition
# -----------------------------
# Change these to your partitions
TARGET_PARTITION="/dev/nvme1n1p4"
MAPPER_NAME="data"
MOUNT_POINT="/mnt/data"
SYMLINK_PATH="$HOME/data"

sudo umount $TARGET_PARTITION 2>/dev/null
sudo umount /dev/mapper/$MAPPER_NAME 2>/dev/null

# -----------------------------
# 4. Format partition with LUKS
# -----------------------------
echo "WARNING: This will erase all data on $TARGET_PARTITION!"
sudo cryptsetup luksFormat $TARGET_PARTITION

# -----------------------------
# 5. Open the LUKS container
# -----------------------------
sudo cryptsetup open $TARGET_PARTITION $MAPPER_NAME

# -----------------------------
# 6. Create a filesystem inside
# -----------------------------
sudo mkfs.ext4 /dev/mapper/$MAPPER_NAME

# -----------------------------
# 7. Mount the encrypted partition
# -----------------------------
sudo mkdir -p $MOUNT_POINT
sudo mount /dev/mapper/$MAPPER_NAME $MOUNT_POINT
echo "Mounted /dev/mapper/$MAPPER_NAME on $MOUNT_POINT"

# -----------------------------
# 8. Create a symlink in home directory
# -----------------------------
# -----------------------------
# 8. Create a symlink in home directory
# -----------------------------
if [ -L "$SYMLINK_PATH" ] || [ -e "$SYMLINK_PATH" ]; then
    echo "Removing existing $SYMLINK_PATH"
    rm -rf "$SYMLINK_PATH"
fi
ln -s $MOUNT_POINT $SYMLINK_PATH
echo "Created symlink: $SYMLINK_PATH -> $MOUNT_POINT"

# Ensure user owns the mount point so they can read/write
sudo chown -R $USER:$USER $MOUNT_POINT
echo "Ownership of $MOUNT_POINT set to $USER"

# 9. Verify
# -----------------------------
df -h | grep $MAPPER_NAME
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
echo

# -----------------------------
# 10. Optional: Configure auto-unlock at boot
# -----------------------------
PART_UUID=$(sudo blkid -s UUID -o value $TARGET_PARTITION)
echo "To enable auto-unlock at boot:"
echo "1. Edit /etc/crypttab and add:"
echo "$MAPPER_NAME UUID=$PART_UUID none luks"
echo
echo "2. Edit /etc/fstab and add:"
echo "/dev/mapper/$MAPPER_NAME $MOUNT_POINT ext4 defaults 0 2"
echo
echo "Then run:"
echo "sudo systemctl daemon-reload"
echo "sudo mount -a"
echo
echo "All done! $MAPPER_NAME is ready to use and symlinked at $SYMLINK_PATH"
