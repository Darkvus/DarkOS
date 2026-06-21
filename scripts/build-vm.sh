#!/bin/bash
set -euo pipefail

# darkOS — Build script para imágenes de VM (VirtualBox .ova / VMware .vmdk)
# Requiere: debootstrap, qemu-utils, qemu-system-x86
# Ejecutar como root en Debian/Ubuntu

DARKOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${DARKOS_ROOT}/build/vm"
ROOTFS="${BUILD_DIR}/rootfs"
RAW_IMG="${BUILD_DIR}/darkOS-1.0-vm.raw"
VMDK_IMG="${DARKOS_ROOT}/build/darkOS-1.0-vm.vmdk"
OVA_DIR="${BUILD_DIR}/ova"
ARCH="amd64"
DISTRO="bookworm"
DISK_SIZE="8G"
VM_NAME="darkOS-1.0"

echo "========================================="
echo "  darkOS Build System — VM Images"
echo "  (VirtualBox .ova + VMware .vmdk)"
echo "========================================="

for dep in debootstrap qemu-img; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: '$dep' no encontrado."
        echo "Instala con: apt install debootstrap qemu-utils"
        exit 1
    fi
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Este script debe ejecutarse como root"
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$ROOTFS" "$OVA_DIR"

# Crear disco raw
echo "[1/8] Creando disco de ${DISK_SIZE}..."
qemu-img create -f raw "$RAW_IMG" "$DISK_SIZE"

# Particionar: 512MB EFI + 1GB boot + resto root
# Debug parted version
parted --version || true

parted -s "$RAW_IMG" mklabel gpt
parted -s "$RAW_IMG" mkpart efi 1MiB 513MiB
parted -s "$RAW_IMG" set 1 esp on
parted -s "$RAW_IMG" mkpart boot 513MiB 1537MiB
parted -s "$RAW_IMG" mkpart root 1537MiB 100%

LOOP=$(losetup --find --show --partscan "$RAW_IMG")
EFI_PART="${LOOP}p1"
BOOT_PART="${LOOP}p2"
ROOT_PART="${LOOP}p3"

mkfs.vfat -F 32 "$EFI_PART"
mkfs.ext4 -q "$BOOT_PART"
mkfs.ext4 -q "$ROOT_PART"

mount "$ROOT_PART" "$ROOTFS"
mkdir -p "${ROOTFS}/boot"
mount "$BOOT_PART" "${ROOTFS}/boot"
mkdir -p "${ROOTFS}/boot/efi"
mount "$EFI_PART" "${ROOTFS}/boot/efi"

# Debootstrap
echo "[2/8] Debootstrap Debian ${DISTRO}..."
debootstrap --arch="$ARCH" "$DISTRO" "$ROOTFS" http://deb.debian.org/debian

# Repos
cat > "${ROOTFS}/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DISTRO} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${DISTRO}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DISTRO}-security main contrib non-free non-free-firmware
EOF

mount -t proc proc "${ROOTFS}/proc"
mount -t sysfs sys "${ROOTFS}/sys"
mount -o bind /dev "${ROOTFS}/dev"
mount -o bind /dev/pts "${ROOTFS}/dev/pts"

# Kernel + GRUB
echo "[3/8] Instalando kernel y bootloader..."
chroot "$ROOTFS" bash -c "
    apt-get update
    apt-get install -y linux-image-amd64 grub-efi-amd64 grub-efi-amd64-bin \
        efibootmgr dosfstools
"

# Instalar paquetes darkOS
echo "[4/8] Instalando paquetes darkOS..."
cp "${DARKOS_ROOT}/packages/pc.list" "${ROOTFS}/tmp/packages.list"
chroot "$ROOTFS" bash -c "
    grep -v '^#' /tmp/packages.list | grep -v '^\$' | xargs apt-get install -y --no-install-recommends
    rm /tmp/packages.list
"

# VM guest additions
echo "[5/8] Instalando guest additions..."
chroot "$ROOTFS" bash -c "
    apt-get install -y --no-install-recommends \
        open-vm-tools open-vm-tools-desktop \
        virtualbox-guest-utils virtualbox-guest-x11 2>/dev/null || \
    apt-get install -y --no-install-recommends \
        open-vm-tools open-vm-tools-desktop 2>/dev/null || true
"

# Scripts de configuración
echo "[6/8] Configurando darkOS..."
for script in setup-dev.sh setup-plasma-mac.sh setup-ollama.sh post-install.sh; do
    cp "${DARKOS_ROOT}/scripts/${script}" "${ROOTFS}/tmp/${script}"
    chmod +x "${ROOTFS}/tmp/${script}"
    chroot "$ROOTFS" bash "/tmp/${script}" || true
    rm -f "${ROOTFS}/tmp/${script}"
done

# Overlays
cp -r "${DARKOS_ROOT}/overlays/"* "${ROOTFS}/" 2>/dev/null || true

# fstab
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PART")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat > "${ROOTFS}/etc/fstab" <<EOF
UUID=${ROOT_UUID}  /          ext4  defaults,noatime  0  1
UUID=${BOOT_UUID}  /boot      ext4  defaults          0  2
UUID=${EFI_UUID}   /boot/efi  vfat  umask=0077        0  1
EOF

# Instalar GRUB
chroot "$ROOTFS" bash -c "
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=darkos --no-nvram --removable 2>/dev/null || true
    update-grub
"

# Habilitar servicios
chroot "$ROOTFS" bash -c "
    systemctl enable ssh
    systemctl enable NetworkManager
    systemctl enable sddm 2>/dev/null || true
    systemctl enable ollama 2>/dev/null || true
    systemctl enable darkos-first-boot 2>/dev/null || true
    systemctl enable darkos-pull-model 2>/dev/null || true
    systemctl set-default graphical.target
"

# Limpiar
chroot "$ROOTFS" apt-get clean

echo "[7/8] Generando imágenes de VM..."
umount "${ROOTFS}/dev/pts"
umount "${ROOTFS}/dev"
umount "${ROOTFS}/sys"
umount "${ROOTFS}/proc"
umount "${ROOTFS}/boot/efi"
umount "${ROOTFS}/boot"
umount "$ROOTFS"
losetup -d "$LOOP"

# Convertir a VMDK (VMware)
qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$RAW_IMG" "$VMDK_IMG"

# Convertir a VDI y crear OVA (VirtualBox)
VDI_IMG="${OVA_DIR}/${VM_NAME}-disk001.vdi"
qemu-img convert -f raw -O vdi "$RAW_IMG" "$VDI_IMG"

# Eliminar raw para liberar espacio
rm -f "$RAW_IMG"

echo "[8/8] Creando OVA..."

# Calcular tamaño del VDI
VDI_SIZE=$(stat -c%s "$VDI_IMG")

# OVF descriptor
cat > "${OVA_DIR}/${VM_NAME}.ovf" <<OVFEOF
<?xml version="1.0"?>
<Envelope ovf:version="2.0"
  xmlns="http://schemas.dmtf.org/ovf/envelope/2"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/2"
  xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"
  xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData"
  xmlns:vbox="http://www.virtualbox.org/ovf/machine">

  <References>
    <File ovf:href="${VM_NAME}-disk001.vdi" ovf:id="file1" ovf:size="${VDI_SIZE}"/>
  </References>

  <DiskSection>
    <Info>Virtual disk information</Info>
    <Disk ovf:capacity="21474836480" ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:format="http://www.virtualbox.org/d/images/vmdk-stream.ovf"/>
  </DiskSection>

  <VirtualSystemCollection ovf:id="${VM_NAME}">
    <VirtualSystem ovf:id="${VM_NAME}">
      <Info>darkOS 1.0 Virtual Machine</Info>
      <OperatingSystemSection ovf:id="96">
        <Info>Debian 12 (64-bit)</Info>
      </OperatingSystemSection>

      <VirtualHardwareSection>
        <Info>Virtual hardware requirements</Info>
        <System>
          <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
          <vssd:InstanceID>0</vssd:InstanceID>
          <vssd:VirtualSystemIdentifier>${VM_NAME}</vssd:VirtualSystemIdentifier>
          <vssd:VirtualSystemType>virtualbox-2.2</vssd:VirtualSystemType>
        </System>

        <Item>
          <rasd:Caption>2 virtual CPUs</rasd:Caption>
          <rasd:Description>Number of Virtual CPUs</rasd:Description>
          <rasd:ElementName>2 virtual CPUs</rasd:ElementName>
          <rasd:InstanceID>1</rasd:InstanceID>
          <rasd:ResourceType>3</rasd:ResourceType>
          <rasd:VirtualQuantity>2</rasd:VirtualQuantity>
        </Item>

        <Item>
          <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
          <rasd:Caption>4096 MB of memory</rasd:Caption>
          <rasd:Description>Memory Size</rasd:Description>
          <rasd:ElementName>4096 MB of memory</rasd:ElementName>
          <rasd:InstanceID>2</rasd:InstanceID>
          <rasd:ResourceType>4</rasd:ResourceType>
          <rasd:VirtualQuantity>4096</rasd:VirtualQuantity>
        </Item>

        <Item>
          <rasd:AddressOnParent>0</rasd:AddressOnParent>
          <rasd:Caption>disk1</rasd:Caption>
          <rasd:Description>Disk Image</rasd:Description>
          <rasd:ElementName>disk1</rasd:ElementName>
          <rasd:HostResource>/disk/vmdisk1</rasd:HostResource>
          <rasd:InstanceID>3</rasd:InstanceID>
          <rasd:ResourceType>17</rasd:ResourceType>
        </Item>

        <Item>
          <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
          <rasd:Caption>Ethernet adapter on NAT</rasd:Caption>
          <rasd:Connection>NAT</rasd:Connection>
          <rasd:ElementName>Ethernet adapter on NAT</rasd:ElementName>
          <rasd:InstanceID>4</rasd:InstanceID>
          <rasd:ResourceSubType>E1000</rasd:ResourceSubType>
          <rasd:ResourceType>10</rasd:ResourceType>
        </Item>
      </VirtualHardwareSection>
    </VirtualSystem>
  </VirtualSystemCollection>
</Envelope>
OVFEOF

# Crear OVA (tar con OVF + VDI)
cd "$OVA_DIR"
tar cf "${DARKOS_ROOT}/build/darkOS-1.0-vm.ova" "${VM_NAME}.ovf" "${VM_NAME}-disk001.vdi"
cd "$DARKOS_ROOT"

# Limpiar temporales
rm -rf "$BUILD_DIR" "$RAW_IMG"

echo "========================================="
echo "  BUILD EXITOSO!"
echo ""
echo "  VirtualBox: build/darkOS-1.0-vm.ova"
echo "  VMware:     build/darkOS-1.0-vm.vmdk"
echo ""
echo "  VirtualBox: File > Import Appliance > darkOS-1.0-vm.ova"
echo "  VMware:     Create VM > Use existing disk > darkOS-1.0-vm.vmdk"
echo "========================================="
