#!/bin/bash
echo "=== compile.h (horodatage de build embarque) ==="
cat /root/linux-next/include/generated/compile.h 2>/dev/null || echo "(absent)"
echo
echo "=== version string dans l'Image ==="
strings /root/linux-next/arch/arm64/boot/Image 2>/dev/null | grep -m1 "Linux version"
echo
echo "=== timestamps fichiers (ISO complet) ==="
ls -la --time-style=full-iso /root/linux-next/arch/arm64/boot/Image /root/sp12/rootfs/boot/Image /root/linux-next/.config /root/linux-next/vmlinux 2>/dev/null
