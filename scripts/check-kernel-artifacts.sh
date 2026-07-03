#!/bin/bash
echo "-- kernel.release --"
cat /root/linux-next/include/config/kernel.release 2>/dev/null || echo "  (pas de .release)"
echo "-- Image compile dans le source linux-next --"
ls -la /root/linux-next/arch/arm64/boot/Image 2>/dev/null || echo "  ABSENT"
echo "-- artefacts dans le rootfs /boot --"
ls -la /root/sp12/rootfs/boot/Image /root/sp12/rootfs/boot/Image.gz /root/sp12/rootfs/boot/initramfs-sp12.img /root/sp12/rootfs/boot/sp12.dtb 2>/dev/null
echo "-- modules compiles --"
ls -d /root/sp12/rootfs/usr/lib/modules/*/ 2>/dev/null || echo "  ABSENT"
echo "-- taille modules --"
du -sh /root/sp12/rootfs/usr/lib/modules 2>/dev/null | tail -1
echo "-- .config du noyau --"
ls -la /root/linux-next/.config 2>/dev/null || echo "  ABSENT"
echo "-- taille arbre source linux-next --"
du -sh /root/linux-next 2>/dev/null | tail -1
