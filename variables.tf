variable "runpod_api_key" {
  type        = string
  description = "Clave API de RunPod (obtener en https://www.runpod.io/console/user/settings)"
  sensitive   = true
}

variable "public_key" {
  type        = string
  description = "Clave SSH pública para acceder al Pod (opcional pero recomendable)"
  default     = ""
}

variable "pod_name" {
  type        = string
  description = "Nombre asignado al Pod en RunPod"
  default     = "comfyui-wan21-rtx4090"
}

variable "gpu_type_id" {
  type        = string
  description = "Tipo de GPU deseada (RTX 4090 para costo < $0.40/hora en Community Cloud)"
  default     = "NVIDIA GeForce RTX 4090"
}

variable "cloud_type" {
  type        = string
  description = "Tipo de nube en RunPod: COMMUNITY (más económica) o SECURE"
  default     = "COMMUNITY"
}

variable "gpu_count" {
  type        = number
  description = "Número de GPUs a asignar"
  default     = 1
}

variable "container_disk_size" {
  type        = number
  description = "Tamaño del disco efímero del contenedor en GB"
  default     = 40
}

variable "volume_size" {
  type        = number
  description = "Tamaño del volumen persistente en GB"
  default     = 80
}

variable "volume_mount_path" {
  type        = string
  description = "Ruta de montaje del volumen persistente"
  default     = "/workspace"
}

variable "container_image" {
  type        = string
  description = "Imagen Docker base idónea con PyTorch y CUDA"
  default     = "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04"
}

variable "comfyui_port" {
  type        = number
  description = "Puerto expuesto para la interfaz web de ComfyUI"
  default     = 8188
}
