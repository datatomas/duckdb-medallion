#!/usr/bin/env bash
# backup_nvme_headers.sh
# Safely back up and restore NVMe headers for encrypted or partitioned disks.
# Use carefully — 1MB per header is enough for LUKS and GPT recovery.
# Author: datatomas

set -euo pipefail

BACKUP_DIR="$HOME/nvme_headers"
mkdir -p "$BACKUP_DIR"

echo "==> Backing up NVMe headers to: $BACKUP_DIR"

# Back up first 1MB from each NVMe device
sudo dd if=/dev/nvme0n1 of="$BACKUP_DIR/nvme0n1-header.img" bs=1M count=1 status=progress
sudo dd if=/dev/nvme1n1 of="$BACKUP_DIR/nvme1n1-header.img" bs=1M count=1 status=progress

echo "==> Backups created:"
ls -lh "$BACKUP_DIR"/*.img

# Optional restore helper
echo ""
echo "To restore a header to a USB recovery drive (⚠️ will overwrite target):"
echo "  sudo dd if=$BACKUP_DIR/nvme0n1-header.img of=/dev/sdX bs=1M count=1 status=progress"
echo "  # or"
echo "  sudo dd if=$BACKUP_DIR/nvme1n1-header.img of=/dev/sdX bs=1M count=1 status=progress"
echo ""
echo "💡 Tip: keep two USBs — one formatted ext4, one ISO-bootable — for field recovery."
