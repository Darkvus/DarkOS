#!/bin/bash
set -euo pipefail

# darkOS — Build script para imagen Raspberry Pi 4 (ARM64)
# Requiere: debootstrap, qemu-user-static, binfmt-support, parted, dosfstools
# Ejecutar como root en Debian/Ubuntu x86_64

DARKOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${DARKOS_ROOT}/build/rpi"
ROOTFS="${BUILD_DIR}/rootfs"
IMG_FILE="${DARKOS_ROOT}/build/darkOS-1.0-rpi.img"
ARCH="arm64"
DISTRO="bookworm"
IMG_SIZE="4G"

echo "========================================="
echo "  darkOS Build System — RPi 4 (ARM64)"
echo "========================================="

# Verificar dependencias
for dep in debootstrap qemu-aarch64-static parted mkfs.vfat mkfs.ext4; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: '$dep' no encontrado."
        echo "Instala con: apt install debootstrap qemu-user-static binfmt-support parted dosfstools"
        exit 1
    fi
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root"
    exit 1
fi

# Limpiar build anterior
rm -rf "$BUILD_DIR" "$IMG_FILE"
mkdir -p "$ROOTFS"

# Crear imagen
echo "[1/6] Creando imagen de ${IMG_SIZE}..."
fallocate -l "$IMG_SIZE" "$IMG_FILE"

# Particionar: 256MB boot (FAT32) + resto root (ext4)
parted -s "$IMG_FILE" mklabel msdos
parted -s "$IMG_FILE" mkpart primary fat32 1MiB 257MiB
parted -s "$IMG_FILE" mkpart primary ext4 257MiB 100%
parted -s "$IMG_FILE" set 1 boot on

# Montar con loop device
LOOP=$(losetup --find --show --partscan "$IMG_FILE")
BOOT_PART="${LOOP}p1"
ROOT_PART="${LOOP}p2"

mkfs.vfat -F 32 "$BOOT_PART"
mkfs.ext4 -q "$ROOT_PART"

mount "$ROOT_PART" "$ROOTFS"
mkdir -p "${ROOTFS}/boot/firmware"
mount "$BOOT_PART" "${ROOTFS}/boot/firmware"

# Debootstrap
echo "[2/6] Debootstrap Debian ${DISTRO} ARM64..."
debootstrap --arch="$ARCH" --foreign "$DISTRO" "$ROOTFS" http://deb.debian.org/debian

# Copiar QEMU para chroot
cp /usr/bin/qemu-aarch64-static "${ROOTFS}/usr/bin/"
chroot "$ROOTFS" /debootstrap/debootstrap --second-stage

# Configurar repos
cat > "${ROOTFS}/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DISTRO} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${DISTRO}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DISTRO}-security main contrib non-free non-free-firmware
EOF

# Montar filesystems para chroot
mount -t proc proc "${ROOTFS}/proc"
mount -t sysfs sys "${ROOTFS}/sys"
mount -o bind /dev "${ROOTFS}/dev"
mount -o bind /dev/pts "${ROOTFS}/dev/pts"

# Instalar kernel y firmware RPi
echo "[3/6] Instalando kernel y firmware RPi..."
chroot "$ROOTFS" bash -c "
    apt-get update
    apt-get install -y linux-image-arm64 firmware-brcm80211 raspi-firmware
"

# Instalar paquetes base
echo "[4/6] Instalando paquetes darkOS..."
cp "${DARKOS_ROOT}/packages/rpi.list" "${ROOTFS}/tmp/packages.list"
chroot "$ROOTFS" bash -c "
    grep -v '^#' /tmp/packages.list | grep -v '^\$' | xargs apt-get install -y --no-install-recommends
    rm /tmp/packages.list
"

# Copiar y ejecutar scripts de configuración
echo "[5/6] Configurando darkOS..."
for script in setup-dev.sh setup-ollama.sh post-install.sh; do
    cp "${DARKOS_ROOT}/scripts/${script}" "${ROOTFS}/tmp/${script}"
    chmod +x "${ROOTFS}/tmp/${script}"
    chroot "$ROOTFS" bash "/tmp/${script}" || true
    rm -f "${ROOTFS}/tmp/${script}"
done

# Script de primer boot para detección de RAM y configuración adaptativa
cat > "${ROOTFS}/usr/local/bin/darkos-first-boot" <<'FIRSTBOOT'
#!/bin/bash
# darkOS — Primer boot: adapta el entorno según hardware
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
MARKER="/var/lib/darkos/.first-boot-done"

if [[ -f "$MARKER" ]]; then
    exit 0
fi

mkdir -p /var/lib/darkos

if [[ $RAM_MB -ge 3500 ]]; then
    echo "darkOS: RAM suficiente (${RAM_MB}MB), instalando KDE Plasma..."
    apt-get install -y --no-install-recommends kde-plasma-desktop sddm konsole dolphin kvantum
    systemctl set-default graphical.target
    systemctl enable sddm
else
    echo "darkOS: RAM limitada (${RAM_MB}MB), usando entorno ligero..."
    systemctl set-default graphical.target
    echo "exec openbox-session" > /home/darkvus/.xinitrc 2>/dev/null || true
fi

touch "$MARKER"
FIRSTBOOT
chmod +x "${ROOTFS}/usr/local/bin/darkos-first-boot"

# Servicio systemd para primer boot
cat > "${ROOTFS}/etc/systemd/system/darkos-first-boot.service" <<EOF
[Unit]
Description=darkOS First Boot Configuration
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/darkos/.first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/darkos-first-boot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chroot "$ROOTFS" systemctl enable darkos-first-boot.service

# Configurar fstab
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PART")
cat > "${ROOTFS}/etc/fstab" <<EOF
UUID=${ROOT_UUID}  /              ext4  defaults,noatime  0  1
UUID=${BOOT_UUID}  /boot/firmware vfat  defaults          0  2
EOF

# Hostname
echo "darkos" > "${ROOTFS}/etc/hostname"

# Limpiar
echo "[6/6] Limpiando y desmontando..."
chroot "$ROOTFS" apt-get clean
rm -f "${ROOTFS}/usr/bin/qemu-aarch64-static"

umount "${ROOTFS}/dev/pts"
umount "${ROOTFS}/dev"
umount "${ROOTFS}/sys"
umount "${ROOTFS}/proc"
umount "${ROOTFS}/boot/firmware"
umount "$ROOTFS"
losetup -d "$LOOP"

echo "========================================="
echo "  BUILD EXITOSO!"
echo "  Imagen: ${IMG_FILE}"
echo "  Flash con: dd if=darkOS-1.0-rpi.img of=/dev/sdX bs=4M status=progress"
echo "  O usar Raspberry Pi Imager"
echo "========================================="
