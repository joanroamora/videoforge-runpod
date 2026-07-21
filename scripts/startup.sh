#!/usr/bin/env bash
###############################################################################
# Script de aprovisionamiento y arranque para ComfyUI + Generación de Video
# Ejecutado automáticamente al iniciar el Pod de RunPod
###############################################################################

set -euo pipefail

LOG_FILE="/workspace/startup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "======================================================================"
echo "[$(date -u)] Iniciando despliegue automatizado de ComfyUI en RunPod..."
echo "======================================================================"

WORKSPACE_DIR="/workspace"
COMFYUI_DIR="${WORKSPACE_DIR}/ComfyUI"

mkdir -p "${WORKSPACE_DIR}"
cd "${WORKSPACE_DIR}"

# -----------------------------------------------------------------------------
# 1. Dependencias del sistema operativo
# -----------------------------------------------------------------------------
echo "--> [1/7] Instalando dependencias del sistema (ffmpeg, aria2, git, etc.)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    aria2 \
    ffmpeg \
    openssh-server \
    libgl1-mesa-glx \
    libglib2.0-0 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    ca-certificates

if [ -n "${PUBLIC_KEY:-}" ]; then
    echo "--> Configurando SSH e inyectando PUBLIC_KEY..."
    mkdir -p /root/.ssh
    echo "${PUBLIC_KEY}" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    service ssh start || true
fi

# -----------------------------------------------------------------------------
# 2. Clonar / Actualizar ComfyUI
# -----------------------------------------------------------------------------
if [ ! -d "${COMFYUI_DIR}" ]; then
    echo "--> [2/7] Clonando el repositorio oficial de ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
else
    echo "--> [2/7] ComfyUI ya existe. Actualizando a la última versión..."
    git -C "${COMFYUI_DIR}" pull || true
fi

cd "${COMFYUI_DIR}"

# -----------------------------------------------------------------------------
# 3. Instalación de paquetes y módulos de Python
# -----------------------------------------------------------------------------
echo "--> [3/7] Instalando requerimientos de PyTorch, CUDA y bibliotecas de IA..."
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
pip install \
    huggingface_hub \
    xformers \
    accelerate \
    diffusers \
    transformers \
    sentencepiece \
    omegaconf \
    opencv-python-headless \
    einops \
    scipy \
    timm

# Instalación de extensiones esenciales (ComfyUI-Manager y VideoHelperSuite)
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"
mkdir -p "${CUSTOM_NODES_DIR}"

if [ ! -d "${CUSTOM_NODES_DIR}/ComfyUI-Manager" ]; then
    echo "--> Instalando extensión ComfyUI-Manager..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "${CUSTOM_NODES_DIR}/ComfyUI-Manager" || true
fi

if [ ! -d "${CUSTOM_NODES_DIR}/ComfyUI-VideoHelperSuite" ]; then
    echo "--> Instalando ComfyUI-VideoHelperSuite (para nodo VideoCombine)..."
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git "${CUSTOM_NODES_DIR}/ComfyUI-VideoHelperSuite" || true
    if [ -f "${CUSTOM_NODES_DIR}/ComfyUI-VideoHelperSuite/requirements.txt" ]; then
        pip install -r "${CUSTOM_NODES_DIR}/ComfyUI-VideoHelperSuite/requirements.txt" || true
    fi
fi

if [ ! -d "${CUSTOM_NODES_DIR}/ComfyUI-WanVideoWrapper" ]; then
    echo "--> Instalando ComfyUI-WanVideoWrapper (nodos avanzados para Wan 2.1)..."
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git "${CUSTOM_NODES_DIR}/ComfyUI-WanVideoWrapper" || true
    if [ -f "${CUSTOM_NODES_DIR}/ComfyUI-WanVideoWrapper/requirements.txt" ]; then
        pip install -r "${CUSTOM_NODES_DIR}/ComfyUI-WanVideoWrapper/requirements.txt" || true
    fi
fi

# -----------------------------------------------------------------------------
# 4. Descarga de modelos: Wan2.1 (Video Gen) y Real-ESRGAN / 4x-UltraSharp (Upscaling)
# -----------------------------------------------------------------------------
CHECKPOINTS_DIR="${COMFYUI_DIR}/models/checkpoints"
VAE_DIR="${COMFYUI_DIR}/models/vae"
CLIP_DIR="${COMFYUI_DIR}/models/clip"
UPSCALE_DIR="${COMFYUI_DIR}/models/upscale_models"
DIFFUSION_DIR="${COMFYUI_DIR}/models/diffusion_models"

mkdir -p "${CHECKPOINTS_DIR}" "${VAE_DIR}" "${CLIP_DIR}" "${UPSCALE_DIR}" "${DIFFUSION_DIR}"

echo "--> [4/7] Descargando modelos de Wan2.1 (I2V + T2V + VAE + Text Encoder)..."
python3 -c "
from huggingface_hub import hf_hub_download
import os, shutil

repo = 'Comfy-Org/Wan_2.1_ComfyUI_repackaged'

# 1. Wan 2.1 Image-to-Video (I2V) 14B FP8 Model
i2v_path = '/workspace/ComfyUI/models/diffusion_models/wan2.1_i2v_480p_14B_fp8_scaled.safetensors'
if not os.path.exists(i2v_path):
    print('  - Descargando Wan 2.1 I2V 14B FP8 Model...')
    f = hf_hub_download(repo_id=repo, filename='split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_scaled.safetensors')
    os.makedirs('/workspace/ComfyUI/models/diffusion_models', exist_ok=True)
    shutil.copy(f, i2v_path)

# 2. Wan 2.1 Text-to-Video (T2V) 1.3B BF16 Model
t2v_path = '/workspace/ComfyUI/models/diffusion_models/wan2.1_t2v_1.3B_bf16.safetensors'
if not os.path.exists(t2v_path):
    print('  - Descargando Wan 2.1 T2V 1.3B BF16 Model...')
    f = hf_hub_download(repo_id=repo, filename='split_files/diffusion_models/wan2.1_t2v_1.3B_bf16.safetensors')
    os.makedirs('/workspace/ComfyUI/models/diffusion_models', exist_ok=True)
    shutil.copy(f, t2v_path)

# 3. Wan 2.1 VAE
vae_path = '/workspace/ComfyUI/models/vae/wan_2.1_vae.safetensors'
if not os.path.exists(vae_path):
    print('  - Descargando Wan 2.1 VAE...')
    f = hf_hub_download(repo_id=repo, filename='split_files/vae/wan_2.1_vae.safetensors')
    os.makedirs('/workspace/ComfyUI/models/vae', exist_ok=True)
    shutil.copy(f, vae_path)

# 4. Text Encoder UMT5-XXL
text_path = '/workspace/ComfyUI/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors'
if not os.path.exists(text_path):
    print('  - Descargando Text Encoder UMT5-XXL...')
    f = hf_hub_download(repo_id=repo, filename='split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors')
    os.makedirs('/workspace/ComfyUI/models/text_encoders', exist_ok=True)
    os.makedirs('/workspace/ComfyUI/models/clip', exist_ok=True)
    shutil.copy(f, text_path)
    shutil.copy(f, '/workspace/ComfyUI/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors')

# 5. Upscaler UltraSharp
up_path = '/workspace/ComfyUI/models/upscale_models/4x-UltraSharp.pth'
if not os.path.exists(up_path):
    print('  - Descargando Upscaler 4x-UltraSharp...')
    f = hf_hub_download(repo_id='uwg/upscaler', filename='ESRGAN/4x-UltraSharp.pth')
    os.makedirs('/workspace/ComfyUI/models/upscale_models', exist_ok=True)
    shutil.copy(f, up_path)
"

# -----------------------------------------------------------------------------
# 5. Instalar Workflows Preconfigurados (I2V + T2V)
# -----------------------------------------------------------------------------
echo "--> [5/7] Configurando Workflows de Wan2.1 (Image-to-Video y Text-to-Video)..."
USER_WORKFLOWS_DIR="${COMFYUI_DIR}/user/default/workflows"
mkdir -p "${USER_WORKFLOWS_DIR}"

if [ -f "${WORKSPACE_DIR}/workflows/wan21_i2v_workflow.json" ]; then
    cp "${WORKSPACE_DIR}/workflows/wan21_i2v_workflow.json" "${USER_WORKFLOWS_DIR}/wan21_i2v_workflow.json"
fi

if [ -f "${WORKSPACE_DIR}/workflows/wan21_video_workflow.json" ]; then
    cp "${WORKSPACE_DIR}/workflows/wan21_video_workflow.json" "${USER_WORKFLOWS_DIR}/wan21_video_workflow.json"
fi

# -----------------------------------------------------------------------------
# 6. Configuración de Túnel Seguro (Cloudflare Tunnel)
# -----------------------------------------------------------------------------
echo "--> [6/7] Instalando y configurando Cloudflare Tunnel para acceso web externo seguro..."
if ! command -v cloudflared &> /dev/null; then
    curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    rm -f /tmp/cloudflared.deb
fi

# Lanzar Cloudflare Quick Tunnel en background y capturar el enlace HTTPS en log
nohup cloudflared tunnel --url http://127.0.0.1:8188 > "${WORKSPACE_DIR}/cloudflared.log" 2>&1 &

# -----------------------------------------------------------------------------
# 7. Lanzar servidor ComfyUI en segundo plano
# -----------------------------------------------------------------------------
echo "--> [7/7] Iniciando servidor ComfyUI escuchando en 0.0.0.0:8188..."
nohup python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE_DIR}/comfyui.log" 2>&1 &

sleep 5
TRY_URL=$(grep -o 'https://[-a-zA-Z0-9.]*\.trycloudflare\.com' "${WORKSPACE_DIR}/cloudflared.log" | tail -n 1 || true)

echo "======================================================================"
echo "[$(date -u)] ¡Despliegue completado! ComfyUI está listo para usarse."
if [ -n "${TRY_URL}" ]; then
    echo "  URL PÚBLICA DE COMFYUI (HTTPS): ${TRY_URL}"
fi
echo "Puedes consultar logs en: ${WORKSPACE_DIR}/comfyui.log y ${WORKSPACE_DIR}/cloudflared.log"
echo "======================================================================"
