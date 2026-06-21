<div align="center">

```
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
```

### A developer-first Linux distro with built-in AI

[![Debian 12](https://img.shields.io/badge/Base-Debian%2012%20Bookworm-A81D33?style=for-the-badge&logo=debian)](https://www.debian.org/)
[![KDE Plasma](https://img.shields.io/badge/Desktop-KDE%20Plasma-1D99F3?style=for-the-badge&logo=kde)](https://kde.org/)
[![Ollama](https://img.shields.io/badge/AI-Ollama-000000?style=for-the-badge)](https://ollama.com/)
[![x86_64](https://img.shields.io/badge/Arch-x86__64-blue?style=for-the-badge&logo=intel)]()
[![ARM64](https://img.shields.io/badge/Arch-ARM64-green?style=for-the-badge&logo=raspberrypi)]()

**Flash. Boot. Code.**

---

</div>

## What is darkOS?

darkOS is a custom Debian 12-based operating system built for developers. It ships with a macOS-styled KDE Plasma desktop, local AI via Ollama, and all the tools you need to start coding — Python, VSCode, Chrome, and more — ready out of the box.

It runs on **PCs** and **Raspberry Pi 4**, adapting automatically to available hardware.

## Features

```
 Code          Python 3, VSCode, Node.js, Git — preinstalled
 AI            Ollama with auto-detected model size
 Desktop       KDE Plasma with macOS aesthetics
 Terminal      Konsole + Starship prompt + dark theme
 Access        SSH always enabled, sudo without password
 Hardware      x86_64 PC and Raspberry Pi 4 (ARM64)
```

## Quick Start

### 1. Build

```bash
# Install build dependencies (Debian/Ubuntu host)
sudo apt install live-build debootstrap qemu-user-static binfmt-support parted dosfstools

# Clone
git clone https://github.com/Darkvus/DarkOS.git && cd DarkOS

# Build for PC
sudo ./scripts/build-pc.sh        # -> build/darkOS-1.0-pc.iso

# Build for Raspberry Pi 4
sudo ./scripts/build-rpi.sh       # -> build/darkOS-1.0-rpi.img
```

### 2. Flash

```bash
# PC — flash to USB
sudo dd if=build/darkOS-1.0-pc.iso of=/dev/sdX bs=4M status=progress

# RPi — flash to SD card (or use Raspberry Pi Imager)
sudo dd if=build/darkOS-1.0-rpi.img of=/dev/sdX bs=4M status=progress
```

### 3. Boot & Code

Default credentials:

| | |
|---|---|
| **User** | `darkvus` |
| **Password** | `darkos` |

## Adaptive Hardware Detection

darkOS detects available RAM on first boot and adapts the experience:

| RAM | Desktop | AI Model | Target |
|:---:|:---:|:---:|:---:|
| **8GB+** | KDE Plasma | `llama3.2:3b` | PC |
| **4GB** | KDE Plasma (lite) | `qwen2:0.5b` | PC / RPi 4 |
| **2GB** | Openbox | `tinyllama` | RPi 4 |
| **1GB** | Openbox | Remote only | RPi 4 |

## Built-in Commands

| Command | What it does |
|:---|:---|
| `darkos-ai` | Smart AI chat — auto-selects local model or remote Ollama |
| `darkos-ai <model>` | Chat with a specific model |
| `code .` | Open VSCode in current directory |
| `python3` | Python interactive shell |

### Remote AI

Connect to an Ollama server on your network when local resources are limited:

```bash
export DARKOS_AI_REMOTE=http://192.168.1.100:11434
darkos-ai
```

## Project Structure

```
darkOS/
├── scripts/
│   ├── build-pc.sh              # Build x86_64 ISO (live-build)
│   ├── build-rpi.sh             # Build ARM64 image (debootstrap + QEMU)
│   ├── setup-dev.sh             # Chrome, VSCode, Node.js, Starship
│   ├── setup-ollama.sh          # Ollama + darkos-ai wrapper
│   ├── setup-plasma-mac.sh      # KDE Plasma macOS theme
│   └── post-install.sh          # Branding, user, SSH
├── overlays/                    # Files copied directly into the image
│   ├── etc/                     # System configs, systemd services
│   ├── usr/local/bin/           # darkos-ai, first-boot, model-pull
│   └── home/skel/              # Default user dotfiles
│       └── .config/            # KDE, Starship, Konsole, Kvantum
├── packages/
│   ├── pc.list                  # Package list for PC image
│   └── rpi.list                 # Package list for RPi image
├── config/
│   └── darkos-branding/         # Logo, issue banner
└── README.md
```

## Desktop Preview

The KDE Plasma desktop is configured with:

- **Top panel** — App menu, global menu, centered clock, system tray
- **Bottom dock** — Floating icon taskbar with Files, Browser, VSCode, Terminal
- **Window buttons on the left** (macOS style: close, minimize, maximize)
- **Breeze Dark** theme with Kvantum styling
- **Borderless maximized windows**
- **2 virtual desktops**

## Tech Stack

| Component | PC (x86_64) | RPi (ARM64) |
|:---|:---|:---|
| Base | Debian 12 Bookworm | Debian 12 Bookworm |
| Build system | `live-build` | `debootstrap` + QEMU |
| Bootloader | GRUB2 | RPi bootloader |
| Output | `.iso` hybrid (USB/DVD) | `.img` (SD/USB) |
| Desktop | KDE Plasma 5 | KDE Plasma 5 / Openbox |
| AI Runtime | Ollama | Ollama |

## Software Included

| Category | Packages |
|:---|:---|
| **Languages** | Python 3.11+, Node.js LTS |
| **Editors** | Visual Studio Code |
| **Browser** | Google Chrome (PC) / Chromium (RPi) |
| **Terminal** | Konsole + Starship prompt |
| **AI** | Ollama + darkos-ai wrapper |
| **Dev tools** | Git, curl, wget, htop, tmux, build-essential |
| **System** | NetworkManager, SSH, Bluetooth, PulseAudio |

---

<div align="center">

**Built by [darkvus](https://github.com/Darkvus)**

</div>
