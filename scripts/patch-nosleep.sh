#!/bin/bash
set -e
IMG=/mnt/c/sp12-linux/sp12.img
echo "=== Desactiver la mise en veille (Snapdragon: suspend/resume casse) ==="
losetup -D 2>/dev/null || true
LOOP=$(losetup -fP --show "$IMG")
mkdir -p /mnt/t
mount "${LOOP}p2" /mnt/t
# 1) masquer les cibles de veille systemd
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  ln -sf /dev/null "/mnt/t/etc/systemd/system/$t"
  echo "  masque: $t"
done
# 2) logind : ne rien faire (idle / lid / boutons)
mkdir -p /mnt/t/etc/systemd/logind.conf.d
cat > /mnt/t/etc/systemd/logind.conf.d/10-nosleep.conf <<'EOF'
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
EOF
echo "  logind: IdleAction=ignore + lid/suspend/hibernate ignores"
echo "=== cmdline (doit contenir usbcore.autosuspend=-1) ==="
grep -o 'linux /boot/Image.*' /mnt/t/boot/grub/grub.cfg
sync
umount /mnt/t
losetup -d "$LOOP"
echo "=== OK image: no-suspend + usbcore.autosuspend=-1 ==="
