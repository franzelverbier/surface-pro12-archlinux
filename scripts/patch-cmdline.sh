#!/bin/bash
set -e
IMG=/mnt/c/sp12-linux/sp12.img
echo "=== Patch cmdline : +usbcore.autosuspend=-1 ==="
losetup -D 2>/dev/null || true
LOOP=$(losetup -fP --show "$IMG")
echo "loop=$LOOP"
mkdir -p /mnt/t
mount "${LOOP}p2" /mnt/t
echo "--- cmdline ACTUELLE ---"
grep -o 'linux /boot/Image.*' /mnt/t/boot/grub/grub.cfg || echo "(grub.cfg introuvable!)"
if grep -q 'usbcore.autosuspend' /mnt/t/boot/grub/grub.cfg; then
  echo "(deja present)"
else
  sed -i 's/loglevel=7/loglevel=7 usbcore.autosuspend=-1/' /mnt/t/boot/grub/grub.cfg
fi
echo "--- cmdline NOUVELLE ---"
grep -o 'linux /boot/Image.*' /mnt/t/boot/grub/grub.cfg
# verif rapide integrite du fs source
echo "--- /boot (image source) ---"
ls -la /mnt/t/boot/ | grep -E 'Image|initramfs-sp12|grub' || true
sync
umount /mnt/t
losetup -d "$LOOP"
echo "=== OK image patchee ==="
