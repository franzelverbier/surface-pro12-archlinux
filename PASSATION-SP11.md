# Passation — Setup Linux Surface Pro 11 (Snapdragon X Elite)

> Document de reprise pour continuer **en session locale**. Résume la discussion menée en web session (cloud) le 2026-07-21.

## 1. Contexte & objectif

- **But :** faire tourner Linux (Arch Linux ARM) sur une **Surface Pro 11** — machine « SP11 Pro » de l'utilisateur.
- Le dépôt de référence existant documente la **Surface Pro 12**, machine voisine mais **pas identique** (voir §3).
- Dépôt GitHub : **`franzelverbier/surface-pro12-archlinux`**
- Branche de travail : **`claude/sp11pro-linux-setup-t2gcaq`**
- Clone local prévu : **`D:\claudegit\surface-pro12-archlinux`**

## 2. Pourquoi on bascule en local (limites de la web session)

La session web s'exécute dans un **conteneur cloud isolé** : elle ne voit **que** le dépôt cloné dans le cloud (`/home/user/surface-pro12-archlinux`). Elle **ne peut pas** :

- lire la **clé USB** ni le dossier « sp12 linux » branché sur la machine ;
- accéder au disque **`D:\claudegit`** ;
- utiliser/déboguer le **MCP « desktop commander »** (serveur local) ;
- profiter de l'**extension filesystem** (extension locale de l'app de bureau).

➡️ Tout ça ne fonctionne **que depuis une session locale** (app Claude Desktop / Claude Code installée sur la machine). C'est la raison du passage en local.

**Test de vérif une fois en local :** demander « liste le contenu de `D:\claudegit` ». Si les vrais fichiers apparaissent → session locale OK.

## 3. Écart matériel important (SP11 ≠ SP12)

| | Dépôt actuel (SP12) | Machine cible (SP11) |
|---|---|---|
| Modèle | Surface Pro 12" (1re éd.) | **Surface Pro 11** |
| SoC | Snapdragon X **Plus** 8-core `x1p42100` | Snapdragon X **Elite** 12-core **`X1E80100`** |
| GPU | Adreno X1-45 | Adreno **X1-85** |

- Le `X1E80100` (SP11) est **mieux supporté en mainline** que le `x1p42100` (SP12).
- La config kernel du dépôt active **déjà** `CLK_X1E80100_GCC/DISPCC` et `PINCTRL_X1E80100` → bonne base de départ.
- **À viser pour le SP11 :** privilégier la **DTB `x1e80100-*` upstream / projet aarch64-laptops** plutôt qu'une DTB maison ; vérifier si un board Surface Pro 11 existe déjà (sinon partir du board Surface le plus proche + adapter).
- **⚠️ À confirmer sur la machine** avant de coder quoi que ce soit : modèle exact, SoC (Elite `X1E80100` vs Plus `X1P64100`), GPU, IDs Wi-Fi/audio/UFS.

## 4. Ce que contient déjà le dépôt (réf. SP12)

```
README.md          # statut composant par composant + how-tos
CHANGELOG.md       # jalons datés (kernel réf. 7.1.0-next-20260626)
kernel/
  config-7.1.0-next-20260626   # .config kernel
  sp12.dtb                     # device tree SP12 (Harrison Vanderbyl)
scripts/
  check-buildtime.sh
  check-kernel-artifacts.sh
  format-backup-disk.ps1
  patch-cmdline.sh
  patch-nosleep.sh             # masque suspend/hibernate (Snapdragon ne resume pas)
  repair-gpt.ps1
  write-linux-sandisk.ps1
```

### Points techniques SP12 réutilisables

- **Kernel :** linux-next (`7.1.0-next-20260626`), `DRM_MSM` + `ATH12K` en modules. **Linux 7.2** doit intégrer le DTS SP12 en mainline.
- **GRUB** arm64-efi (`BOOTAA64.EFI` sur l'ESP) charge `Image` + initramfs + DTB. Install root sur **ext4 interne**, dual-boot Windows.
- **Codec vidéo (iris) :** nécessite `qcvss8380_pa.mbn` (absent de linux-firmware), à extraire du DriverStore Windows → `/lib/firmware/qcom/.../qcvss8380_pa.mbn`. **Ne pas blacklister `qcom_iris`.** Accel via **V4L2 m2m** (`/dev/video0/1`), pas VA-API.
- **Audio :** topology AudioReach dans linux-firmware ; ADSP `qcadsp8380.mbn`. → `q6apm`, jack casque OK, PipeWire.
- **Wi-Fi :** ath12k / WCN7850 (FastConnect 7800).
- **Batterie :** jauge via `energy_*`/UPower OK ; `charge_*`/`capacity` = ENODATA (régression upstream, sans impact desktop).
- **Stabilité :**
  - **Pas de resume** → masquer sleep/suspend/hibernate + logind `IdleAction=ignore`, `HandleLidSwitch=ignore`.
  - **USB fragile sous charge** → `usbcore.autosuspend=-1`, éviter I/O simultanée sur 2 SSD USB.
  - **`pacman -Syu` sûr** → `IgnorePkg` sur `linux-aarch64`, `systemd`, `mesa`, `vulkan-freedreno`, `mkinitcpio`, `linux-firmware*` + `--ignore vulkan-mesa-implicit-layers` (garder tout le userspace Mesa/Vulkan sur **une** version).
  - **NTFS partagé** → fstab `nofail,x-systemd.automount` via `ntfs-3g` (pas de `ntfs3` en tree).

## 5. Prochaines étapes (à faire en local)

1. **Vérifier qu'on est bien en local** (`D:\claudegit` visible).
2. **Cloner / synchroniser le dépôt** si pas déjà fait :
   ```powershell
   cd D:\claudegit
   git clone https://github.com/franzelverbier/surface-pro12-archlinux.git
   cd surface-pro12-archlinux
   git fetch origin claude/sp11pro-linux-setup-t2gcaq
   git checkout claude/sp11pro-linux-setup-t2gcaq
   ```
3. **Identifier précisément le SP11** (depuis le Linux live ou Windows) :
   - SoC/CPU : `cat /proc/cpuinfo`, `lscpu` ; sous Windows : `Get-WmiObject Win32_Processor`.
   - GPU/DTB, IDs PCI Wi-Fi, carte audio, UFS.
4. **Régler le MCP « desktop commander »** en local (vérifier `claude_desktop_config.json`, logs de démarrage).
5. **Lire le dossier « sp12 linux » de la clé USB** (me le pointer une fois en local).
6. **Créer la base doc/kernel SP11** : nouvelle section/README dédié `X1E80100`, DTB upstream visée, deltas de config vs SP12.

## 6. Questions ouvertes à trancher

- Modèle/SoC exact du SP11 confirmés ? (Elite `X1E80100` vs Plus `X1P64100`)
- On repart d'une **DTB upstream** SP11 ou on adapte la DTB SP12 ?
- Nouveau dépôt/branche dédié SP11, ou on garde tout dans `surface-pro12-archlinux` avec une section SP11 ?
- Contenu réel du dossier « sp12 linux » sur la clé USB (kernel déjà compilé ? firmwares ? images ?).
