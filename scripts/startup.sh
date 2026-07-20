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
    libgl1-mesa-glx \
    libglib2.0-0 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    ca-certificates

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

echo "--> [4/7] Descargando pesos de modelos open-source..."

# A) Modelo de Generación de Video Wan2.1 (Model / VAE / Text Encoder)
if [ ! -f "${DIFFUSION_DIR}/wan2.1_t2v_1.3B_bf16.safetensors" ]; then
    echo "    - Descargando Wan2.1 T2V 1.3B Diffusion Model..."
    aria2c -x 16 -s 16 -k 1M -d "${DIFFUSION_DIR}" -o "wan2.1_t2v_1.3B_bf16.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repack/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_bf16.safetensors" || true
fi

if [ ! -f "${VAE_DIR}/wan_2.1_vae.safetensors" ]; then
    echo "    - Descargando VAE Wan2.1..."
    aria2c -x 16 -s 16 -k 1M -d "${VAE_DIR}" -o "wan_2.1_vae.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repack/resolve/main/split_files/vae/wan_2.1_vae.safetensors" || true
fi

if [ ! -f "${CLIP_DIR}/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo "    - Descargando Text Encoder UMT5-XXL..."
    aria2c -x 16 -s 16 -k 1M -d "${CLIP_DIR}" -o "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repack/resolve/main/split_files/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" || true
fi

# B) Modelo de Upscaling Eficiente (Real-ESRGAN / 4x-UltraSharp)
if [ ! -f "${UPSCALE_DIR}/4x-UltraSharp.pth" ]; then
    echo "    - Descargando Modelo Upscaler 4x-UltraSharp / Real-ESRGAN..."
    aria2c -x 16 -s 16 -k 1M -d "${UPSCALE_DIR}" -o "4x-UltraSharp.pth" \
        "https://huggingface.co/lokidv/4x-UltraSharp/resolve/main/4x-UltraSharp.pth" || true
fi

# -----------------------------------------------------------------------------
# 5. Instalar Workflow Preconfigurado de Wan2.1 Video
# -----------------------------------------------------------------------------
echo "--> [5/7] Configurando Workflow predeterminado de Wan2.1 Video Generation..."
USER_WORKFLOWS_DIR="${COMFYUI_DIR}/user/default/workflows"
mkdir -p "${USER_WORKFLOWS_DIR}"

cat << 'EOF' > "${USER_WORKFLOWS_DIR}/wan21_video_workflow.json"
{
  "last_node_id": 10,
  "last_link_id": 12,
  "nodes": [
    {
      "id": 1,
      "type": "LoadImage",
      "pos": [50, 100],
      "size": [315, 314],
      "flags": {},
      "order": 0,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": []},
        {"name": "MASK", "type": "MASK", "links": []}
      ],
      "properties": {"Node name for JS": "LoadImage"},
      "widgets_values": ["input_cinematic_base.png", "image"]
    },
    {
      "id": 2,
      "type": "UNETLoader",
      "pos": [400, 50],
      "size": [350, 82],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [2]}
      ],
      "properties": {"Node name for JS": "UNETLoader"},
      "widgets_values": ["wan2.1_t2v_1.3B_bf16.safetensors", "default"]
    },
    {
      "id": 8,
      "type": "CLIPLoader",
      "pos": [400, 170],
      "size": [350, 82],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "CLIP", "type": "CLIP", "links": [3, 11]}
      ],
      "properties": {"Node name for JS": "CLIPLoader"},
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors", "wan"]
    },
    {
      "id": 9,
      "type": "VAELoader",
      "pos": [400, 290],
      "size": [350, 82],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "VAE", "type": "VAE", "links": [8]}
      ],
      "properties": {"Node name for JS": "VAELoader"},
      "widgets_values": ["wan_2.1_vae.safetensors"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [400, 410],
      "size": [400, 180],
      "flags": {},
      "order": 4,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "links": [3]}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [4]}
      ],
      "properties": {"Node name for JS": "CLIPTextEncode"},
      "widgets_values": [
        "Cinematic masterclass video, an epic professional shot, anamorphic lens flare, shallow depth of field, 35mm film grain, moody cinematic lighting, dramatic color grading, photorealistic, fluid natural motion. A futuristic drone flying over a cybernetic neon city at night."
      ]
    },
    {
      "id": 5,
      "type": "CLIPTextEncode",
      "pos": [400, 620],
      "size": [400, 140],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "links": [11]}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5]}
      ],
      "properties": {"Node name for JS": "CLIPTextEncode"},
      "widgets_values": [
        "low quality, blurry, distorted, jittery motion, abrupt cuts, deformed anatomy, artifacts, overexposed, static image."
      ]
    },
    {
      "id": 10,
      "type": "EmptyWanVideoLatent",
      "pos": [400, 790],
      "size": [315, 106],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [6]}
      ],
      "properties": {"Node name for JS": "EmptyWanVideoLatent"},
      "widgets_values": [832, 480, 81, 1]
    },
    {
      "id": 4,
      "type": "KSampler",
      "pos": [850, 100],
      "size": [300, 470],
      "flags": {},
      "order": 7,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "links": [2]},
        {"name": "positive", "type": "CONDITIONING", "links": [4]},
        {"name": "negative", "type": "CONDITIONING", "links": [5]},
        {"name": "latent_image", "type": "LATENT", "links": [6]}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7]}
      ],
      "properties": {"Node name for JS": "KSampler"},
      "widgets_values": [
        1337,
        "randomize",
        30,
        6.5,
        "euler",
        "normal",
        1.0
      ]
    },
    {
      "id": 6,
      "type": "VAEDecode",
      "pos": [1200, 100],
      "size": [210, 80],
      "flags": {},
      "order": 8,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "links": [7]},
        {"name": "vae", "type": "VAE", "links": [8]}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [9]}
      ],
      "properties": {"Node name for JS": "VAEDecode"},
      "widgets_values": []
    },
    {
      "id": 7,
      "type": "VideoCombine",
      "pos": [1450, 100],
      "size": [315, 300],
      "flags": {},
      "order": 9,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "links": [9]}
      ],
      "outputs": [],
      "properties": {"Node name for JS": "VideoCombine"},
      "widgets_values": {
        "frame_rate": 24,
        "format": "video/h264-mp4",
        "crf": 19,
        "save_output": true
      }
    }
  ],
  "links": [
    [2, 2, 0, 4, 0, "MODEL"],
    [3, 8, 0, 3, 0, "CLIP"],
    [4, 3, 0, 4, 1, "CONDITIONING"],
    [5, 5, 0, 4, 2, "CONDITIONING"],
    [6, 10, 0, 4, 3, "LATENT"],
    [7, 4, 0, 6, 0, "LATENT"],
    [8, 9, 0, 6, 1, "VAE"],
    [9, 6, 0, 7, 0, "IMAGE"],
    [11, 8, 0, 5, 0, "CLIP"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
EOF

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
