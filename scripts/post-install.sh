#!/bin/bash
set -euo pipefail

# darkOS — Configuración post-instalación

echo "[darkOS] Ejecutando post-instalación..."

# OS Release branding
cat > /etc/os-release <<'EOF'
PRETTY_NAME="darkOS 1.0"
NAME="darkOS"
VERSION_ID="1.0"
VERSION="1.0 (Bookworm)"
ID=darkos
ID_LIKE=debian
HOME_URL="https://github.com/darkvus/darkOS"
BUG_REPORT_URL="https://github.com/darkvus/darkOS/issues"
EOF

# Crear usuario default
if ! id darkvus &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth darkvus
    echo "darkvus:darkos" | chpasswd
    echo "[darkOS] Usuario 'darkvus' creado (password: darkos)"
fi

# SSH habilitado siempre
systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true

# Hostname
echo "darkos" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
127.0.1.1   darkos

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# NetworkManager
systemctl enable NetworkManager 2>/dev/null || true

# Neofetch custom con logo darkOS
mkdir -p /etc/skel/.config/neofetch
cat > /etc/skel/.config/neofetch/config.conf <<'NEOFETCH'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "DE" de
    info "Terminal" term
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info "Disk" disk
    info "Local IP" local_ip
    info cols
}

ascii_distro="auto"
NEOFETCH

# ASCII logo custom para neofetch
cat > /etc/skel/.config/neofetch/ascii.txt <<'ASCII'
     ██████╗  █████╗ ██████╗ ██╗  ██╗
     ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝
     ██║  ██║███████║██████╔╝█████╔╝
     ██║  ██║██╔══██║██╔══██╗██╔═██╗
     ██████╔╝██║  ██║██║  ██║██║  ██╗
     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝
      ██████╗ ███████╗
     ██╔═══██╗██╔════╝
     ██║   ██║███████╗
     ██║   ██║╚════██║
     ╚██████╔╝███████║
      ╚═════╝ ╚══════╝
ASCII

# MOTD
cat > /etc/motd <<'MOTD'

  ╔══════════════════════════════════════╗
  ║           Welcome to darkOS          ║
  ║     Powered by Debian + Ollama       ║
  ╠══════════════════════════════════════╣
  ║  darkos-ai  → Chat con IA local     ║
  ║  code .     → Abrir VSCode          ║
  ║  python3    → Python interactivo     ║
  ╚══════════════════════════════════════╝

MOTD

# Sudoers sin password para grupo sudo (desarrollo)
echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/darkos-nopasswd

# Limpiar
apt-get autoremove -y 2>/dev/null || true
apt-get clean 2>/dev/null || true

echo "[darkOS] Post-instalación completada."
