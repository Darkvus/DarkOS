#!/bin/bash
set -euo pipefail

# darkOS — Configurar KDE Plasma con estética macOS

echo "[darkOS] Configurando KDE Plasma estilo macOS..."

SKEL="/etc/skel"
PLASMA_DIR="${SKEL}/.config"
LOCAL_SHARE="${SKEL}/.local/share"

mkdir -p "${PLASMA_DIR}" "${LOCAL_SHARE}/plasma/desktoptheme"
mkdir -p "${SKEL}/.local/share/konsole"

# Tema Kvantum (WhiteSur-dark)
mkdir -p "${PLASMA_DIR}/Kvantum"
cat > "${PLASMA_DIR}/Kvantum/kvantumrc" <<'EOF'
[General]
theme=KvArcDark
EOF

# Configuración de Plasma — panel superior estilo macOS
cat > "${PLASMA_DIR}/plasma-org.kde.plasma.desktop-appletsrc" <<'EOF'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.desktopcontainment
wallpaperplugin=org.kde.image

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel

[Containments][2][Applets][3]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.appmenu

[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][2][Applets][6]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][7]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][2][Applets][8]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][2][General]
AppletOrder=3;4;5;6;7;8
EOF

# Tema oscuro global
cat > "${PLASMA_DIR}/kdeglobals" <<'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
widgetStyle=kvantum-dark

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
EOF

# Configuración de ventanas — botones estilo macOS (cerrar, min, max a la izquierda)
cat > "${PLASMA_DIR}/kwinrc" <<'EOF'
[org.kde.kdecoration2]
ButtonsOnLeft=XIA
ButtonsOnRight=
library=org.kde.breeze
theme=Breeze

[Compositing]
Backend=OpenGL
Enabled=true
GLCore=true
AnimationSpeed=3

[Effect-Overview]
BorderActivate=9

[Desktops]
Number=2
Rows=1

[Windows]
BorderlessMaximizedWindows=true
EOF

# Dock inferior (taskbar como dock macOS)
cat > "${PLASMA_DIR}/plasmashellrc" <<'EOF'
[PlasmaViews][Panel 3]
floating=1
panelLengthMode=1

[PlasmaViews][Panel 3][Defaults]
thickness=48
EOF

# Konsole — terminal oscura
cat > "${SKEL}/.local/share/konsole/darkOS.profile" <<'EOF'
[Appearance]
ColorScheme=Breeze
Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0

[General]
Command=/bin/bash
Name=darkOS
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
EOF

cat > "${PLASMA_DIR}/konsolerc" <<'EOF'
[Desktop Entry]
DefaultProfile=darkOS.profile

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
EOF

# SDDM tema oscuro
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/darkos.conf <<'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors

[General]
InputMethod=

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

echo "[darkOS] KDE Plasma configurado con estilo macOS."
