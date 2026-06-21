#!/bin/bash
set -euo pipefail

# darkOS — Instalación y configuración de Ollama

echo "[darkOS] Configurando Ollama..."

# Instalar Ollama
curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true

# Crear servicio systemd para Ollama
cat > /etc/systemd/system/ollama.service <<'SERVICE'
[Unit]
Description=Ollama LLM Server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0"
User=ollama
Group=ollama

[Install]
WantedBy=multi-user.target
SERVICE

# Crear usuario ollama si no existe
id ollama &>/dev/null || useradd -r -s /bin/false -d /usr/share/ollama ollama
mkdir -p /usr/share/ollama
chown ollama:ollama /usr/share/ollama

systemctl daemon-reload 2>/dev/null || true
systemctl enable ollama 2>/dev/null || true

# Script wrapper darkos-ai
cat > /usr/local/bin/darkos-ai <<'WRAPPER'
#!/bin/bash
# darkOS AI — Wrapper inteligente para Ollama

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
OLLAMA_LOCAL="http://localhost:11434"
OLLAMA_REMOTE="${DARKOS_AI_REMOTE:-}"

check_ollama() {
    curl -sf "$1/api/tags" &>/dev/null
}

get_models() {
    curl -sf "$1/api/tags" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f\"  - {m['name']} ({m['size']//1048576}MB)\")
" 2>/dev/null
}

echo "╔══════════════════════════════════════╗"
echo "║         darkOS AI Assistant          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "RAM disponible: ${RAM_MB}MB"

# Intentar local primero
if check_ollama "$OLLAMA_LOCAL"; then
    echo "Estado: Ollama local activo ✓"
    echo "Modelos disponibles:"
    get_models "$OLLAMA_LOCAL"
    echo ""

    if [[ $# -gt 0 ]]; then
        MODEL="$1"
    else
        # Seleccionar modelo default según RAM
        if [[ $RAM_MB -ge 8000 ]]; then
            MODEL="llama3.2:3b"
        elif [[ $RAM_MB -ge 3500 ]]; then
            MODEL="qwen2:0.5b"
        else
            MODEL="tinyllama"
        fi
    fi

    echo "Iniciando chat con ${MODEL}..."
    echo "(Ctrl+D para salir)"
    echo ""
    ollama run "$MODEL"

elif [[ -n "$OLLAMA_REMOTE" ]] && check_ollama "$OLLAMA_REMOTE"; then
    echo "Estado: Conectado a Ollama remoto (${OLLAMA_REMOTE}) ✓"
    echo "Modelos disponibles:"
    get_models "$OLLAMA_REMOTE"
    echo ""
    echo "Usa: OLLAMA_HOST=${OLLAMA_REMOTE} ollama run <modelo>"

else
    echo "Estado: Sin servidor Ollama disponible"
    echo ""
    echo "Opciones:"
    echo "  1. Iniciar Ollama local:  sudo systemctl start ollama"
    echo "  2. Descargar un modelo:   ollama pull tinyllama"
    echo "  3. Conectar a remoto:     export DARKOS_AI_REMOTE=http://<ip>:11434"
    echo ""

    if [[ $RAM_MB -ge 8000 ]]; then
        echo "Recomendado para tu RAM: ollama pull llama3.2:3b"
    elif [[ $RAM_MB -ge 3500 ]]; then
        echo "Recomendado para tu RAM: ollama pull qwen2:0.5b"
    elif [[ $RAM_MB -ge 1500 ]]; then
        echo "Recomendado para tu RAM: ollama pull tinyllama"
    else
        echo "RAM muy limitada. Recomendado: usar Ollama remoto desde otro PC."
    fi
fi
WRAPPER
chmod +x /usr/local/bin/darkos-ai

# Script para descargar modelo recomendado al primer boot
cat > /usr/local/bin/darkos-pull-model <<'PULL'
#!/bin/bash
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
MARKER="/var/lib/darkos/.model-pulled"

if [[ -f "$MARKER" ]]; then
    exit 0
fi

sleep 10
if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
    exit 0
fi

if [[ $RAM_MB -ge 8000 ]]; then
    ollama pull llama3.2:3b
elif [[ $RAM_MB -ge 3500 ]]; then
    ollama pull qwen2:0.5b
elif [[ $RAM_MB -ge 1500 ]]; then
    ollama pull tinyllama
fi

mkdir -p /var/lib/darkos
touch "$MARKER"
PULL
chmod +x /usr/local/bin/darkos-pull-model

# Servicio para pull automático
cat > /etc/systemd/system/darkos-pull-model.service <<'SERVICE'
[Unit]
Description=darkOS — Download recommended AI model
After=ollama.service
Wants=ollama.service
ConditionPathExists=!/var/lib/darkos/.model-pulled

[Service]
Type=oneshot
ExecStart=/usr/local/bin/darkos-pull-model
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload 2>/dev/null || true
systemctl enable darkos-pull-model 2>/dev/null || true

echo "[darkOS] Ollama configurado."
