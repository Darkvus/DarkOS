#!/bin/bash
set -euo pipefail

# darkOS — Configuración de herramientas de desarrollo

echo "[darkOS] Configurando entorno de desarrollo..."

# Python ya viene de la lista de paquetes, configurar pip
python3 -m pip install --upgrade pip 2>/dev/null || true

# Google Chrome (solo x86_64, en ARM64 se usa Chromium)
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" == "amd64" ]]; then
    echo "[darkOS] Instalando Google Chrome..."
    wget -q -O /tmp/chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    apt-get install -y /tmp/chrome.deb || true
    rm -f /tmp/chrome.deb
else
    echo "[darkOS] ARM64 detectado, instalando Chromium..."
    apt-get install -y chromium || true
fi

# VSCode
echo "[darkOS] Instalando Visual Studio Code..."
if [[ "$ARCH" == "amd64" ]]; then
    wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    apt-get install -y /tmp/vscode.deb || true
    rm -f /tmp/vscode.deb
else
    wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
    apt-get install -y /tmp/vscode.deb || true
    rm -f /tmp/vscode.deb
fi

# Node.js LTS
echo "[darkOS] Instalando Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>/dev/null || true
apt-get install -y nodejs 2>/dev/null || true

# Starship prompt
echo "[darkOS] Instalando Starship prompt..."
curl -fsSL https://starship.rs/install.sh | sh -s -- -y 2>/dev/null || true

# Configurar Starship para todos los usuarios nuevos
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/starship.toml <<'STARSHIP'
format = """
[░▒▓](#1a1b26)\
$os\
$username\
[](bg:#7aa2f7 fg:#1a1b26)\
$directory\
[](fg:#7aa2f7 bg:#394260)\
$git_branch\
$git_status\
[](fg:#394260 bg:#1d2230)\
$python\
$nodejs\
[](fg:#1d2230)\
$character"""

[os]
disabled = false
style = "bg:#1a1b26 fg:#7aa2f7"

[os.symbols]
Linux = "󰌽 "

[username]
show_always = true
style_user = "bg:#1a1b26 fg:#c0caf5"
format = '[$user ]($style)'

[directory]
style = "bg:#7aa2f7 fg:#1a1b26"
format = "[ $path ]($style)"
truncation_length = 3

[git_branch]
style = "bg:#394260 fg:#c0caf5"
format = '[ $symbol$branch ]($style)'

[git_status]
style = "bg:#394260 fg:#c0caf5"
format = '[$all_status$ahead_behind ]($style)'

[python]
style = "bg:#1d2230 fg:#c0caf5"
format = '[ $symbol$version ]($style)'

[nodejs]
style = "bg:#1d2230 fg:#c0caf5"
format = '[ $symbol$version ]($style)'

[character]
success_symbol = "[❯](bold #7aa2f7)"
error_symbol = "[❯](bold #f7768e)"
STARSHIP

# Agregar Starship al bashrc default
cat >> /etc/skel/.bashrc <<'BASHRC'

# darkOS — Starship prompt
eval "$(starship init bash)"

# darkOS — Aliases útiles
alias ll='ls -lah --color=auto'
alias gs='git status'
alias gd='git diff'
alias py='python3'
alias darkos-ai='/usr/local/bin/darkos-ai'
BASHRC

echo "[darkOS] Entorno de desarrollo configurado."
