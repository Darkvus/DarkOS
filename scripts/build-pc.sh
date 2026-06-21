#!/bin/bash
set -euo pipefail

# darkOS — Build script para imagen PC (x86_64)
# Requiere: live-build, debootstrap
# Ejecutar como root en Debian/Ubuntu

DARKOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${DARKOS_ROOT}/build/pc"
ARCH="amd64"
DISTRO="bookworm"

echo "========================================="
echo "  darkOS Build System — PC (x86_64)"
echo "========================================="

# Verificar dependencias
for dep in lb debootstrap; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: '$dep' no encontrado. Instala con: apt install live-build debootstrap"
        exit 1
    fi
done

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root"
    exit 1
fi

# Preparar directorio de build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configurar live-build
# Debug: show lb version and available options
lb --version || true
echo "---"

lb config \
    --distribution "$DISTRO" \
    --architecture "$ARCH" \
    --binary-image iso-hybrid \
    --debian-installer none \
    --memtest none \
    --apt-recommends false

# Copiar lista de paquetes
cp "${DARKOS_ROOT}/packages/pc.list" config/package-lists/darkos.list.chroot

# Copiar hooks de configuración
mkdir -p config/hooks/normal
cp "${DARKOS_ROOT}/scripts/setup-dev.sh" config/hooks/normal/0100-setup-dev.hook.chroot
cp "${DARKOS_ROOT}/scripts/setup-plasma-mac.sh" config/hooks/normal/0200-setup-plasma.hook.chroot
cp "${DARKOS_ROOT}/scripts/setup-ollama.sh" config/hooks/normal/0300-setup-ollama.hook.chroot
cp "${DARKOS_ROOT}/scripts/post-install.sh" config/hooks/normal/0400-post-install.hook.chroot
chmod +x config/hooks/normal/*.hook.chroot

# Copiar overlays (archivos que van directo al filesystem)
if [[ -d "${DARKOS_ROOT}/overlays" ]]; then
    cp -r "${DARKOS_ROOT}/overlays/"* config/includes.chroot/ 2>/dev/null || true
fi

# Copiar branding
mkdir -p config/includes.chroot/usr/share/darkos
cp -r "${DARKOS_ROOT}/config/darkos-branding/"* config/includes.chroot/usr/share/darkos/ 2>/dev/null || true

echo "Iniciando build... (esto puede tardar 20-40 minutos)"
lb build 2>&1 | tee "${DARKOS_ROOT}/build/pc-build.log"

ISO_FILE=$(find . -maxdepth 1 -name "*.iso" | head -1)
if [[ -n "$ISO_FILE" ]]; then
    mv "$ISO_FILE" "${DARKOS_ROOT}/build/darkOS-1.0-pc.iso"
    echo "========================================="
    echo "  BUILD EXITOSO!"
    echo "  ISO: ${DARKOS_ROOT}/build/darkOS-1.0-pc.iso"
    echo "  Flash con: dd if=darkOS-1.0-pc.iso of=/dev/sdX bs=4M status=progress"
    echo "========================================="
else
    echo "ERROR: No se generó la ISO"
    exit 1
fi
