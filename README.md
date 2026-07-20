# 🚀 Despliegue Automatizado de ComfyUI en RunPod con Terraform (NVIDIA RTX 4090)

Este proyecto proporciona la infraestructura como código (IaC) completa mediante **Terraform** para desplegar un Pod en **RunPod (Community Cloud)** aprovechando la potencia de una GPU **NVIDIA GeForce RTX 4090 (24 GB VRAM)** por menos de **$0.40 USD/hora**.

El entorno se provisiona de forma 100% automatizada con **ComfyUI**, dependencias optimizadas de CUDA/PyTorch, el modelo **Wan2.1 (Text-to-Video)**, **UMT5-XXL Text Encoder**, **VAE Wan2.1**, y el upscaler **Real-ESRGAN / 4x-UltraSharp**. Además, expone un túnel seguro e interfaz HTTPS directamente accesible desde cualquier navegador.

---

## 📁 Estructura del Proyecto

```text
.
├── provider.tf             # Configuración del proveedor oficial de RunPod para Terraform
├── variables.tf            # Definición de variables reutilizables (API key, GPU, discos, etc.)
├── main.tf                 # Recurso principal runpod_pod y script de inicio
├── outputs.tf              # Salidas útiles (Pod ID, URL proxy de ComfyUI, SSH command)
├── terraform.tfvars.example # Plantilla de configuración de variables locales
└── scripts/
    └── startup.sh          # Script de aprovisionamiento automatizado en Bash
```

---

## 📋 Requisitos Previos

1. **Terraform CLI** instalado (versión `>= 1.5.0`). [Descargar Terraform](https://developer.hashicorp.com/terraform/downloads)
2. **Cuenta activa en RunPod** con saldo disponible y una **API Key**. Generar clave en [RunPod Console -> Settings](https://www.runpod.io/console/user/settings).
3. Clave SSH pública (opcional, si deseas ingresar al Pod vía SSH).

---

## 🛠️ Paso a Paso para Configuración y Despliegue

### 1. Configurar Credenciales y Variables

Puedes definir tus variables creando un archivo `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus credenciales:

```hcl
runpod_api_key = "rpa_TU_CLAVE_API_DE_RUNPOD"
public_key     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... tu_clave_ssh_publica"
pod_name       = "comfyui-wan21-rtx4090"
gpu_type_id    = "NVIDIA GeForce RTX 4090"
cloud_type     = "COMMUNITY"
gpu_count      = 1
```

> **Alternativa por variables de entorno:**
> ```bash
> export TF_VAR_runpod_api_key="rpa_TU_CLAVE_API_DE_RUNPOD"
> ```

---

### 2. Inicializar Terraform

Descarga e inicializa el proveedor de RunPod:

```bash
terraform init
```

---

### 3. Planificar el Despliegue

Verifica la infraestructura que se creará:

```bash
terraform plan
```

---

### 4. Aplicar y Desplegar el Pod

Ejecuta el despliegue automático:

```bash
terraform apply -auto-approve
```

---

## 🌐 Acceso a la Interfaz Web de ComfyUI

Una vez completado el `terraform apply`, la salida de la consola mostrará los enlaces de acceso:

```text
Outputs:

comfyui_runpod_proxy_url = "https://<POD_ID>-8188.proxy.runpod.net"
pod_id                   = "<POD_ID>"
ssh_connection_command   = "ssh root@<POD_ID>.proxy.runpod.net"
```

### Opciones de acceso HTTPS:
1. **RunPod Proxy Nativo (Recomendado):** Abre en tu navegador la URL devuelta en `comfyui_runpod_proxy_url`.
2. **Cloudflare Tunnel:** Se genera automáticamente un enlace `.trycloudflare.com`. Para obtenerlo, conecta por SSH o Web Terminal y ejecuta:
   ```bash
   cat /workspace/cloudflared.log | grep trycloudflare.com
   ```

> ⏳ **Nota sobre la descarga de modelos:** El arranque inicial toma unos 2 a 3 minutos mientras se descargan las dependencias y los pesos de Wan2.1. Puedes monitorear el progreso del script de inicio ejecutando:
> ```bash
> tail -f /workspace/startup.log
> ```

---

## 📽️ Modelos Preinstalados

- **Generación de Video:** Wan2.1 T2V 1.3B (`models/diffusion_models/wan2.1_t2v_1.3B_bf16.safetensors`)
- **Text Encoder:** UMT5-XXL FP8 (`models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors`)
- **VAE:** Wan2.1 VAE (`models/vae/wan_2.1_vae.safetensors`)
- **Upscaling / Mejora:** Real-ESRGAN / 4x-UltraSharp (`models/upscale_models/4x-UltraSharp.pth`)

---

## 🧹 Limpieza / Destrucción de la Infraestructura

Para apagar el Pod y detener los cobros por hora en RunPod, ejecuta:

```bash
terraform destroy -auto-approve
```

---

## 🛡️ Mejores Prácticas de Producción y Seguridad

- **No comites `terraform.tfvars`** al control de versiones (`git`).
- Los volúmenes persistentes se montan en `/workspace`, lo que conserva tus flujos de trabajo de ComfyUI si reinicias el Pod.
