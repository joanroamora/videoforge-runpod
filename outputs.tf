output "pod_id" {
  description = "ID único del Pod creado en RunPod"
  value       = runpod_pod.comfyui_pod.id
}

output "pod_name" {
  description = "Nombre asignado al Pod"
  value       = runpod_pod.comfyui_pod.name
}

output "gpu_type" {
  description = "Modelo de GPU contratado"
  value       = runpod_pod.comfyui_pod.gpu_type_id
}

output "comfyui_runpod_proxy_url" {
  description = "Enlace HTTPS nativo del Proxy HTTP de RunPod para acceder a ComfyUI"
  value       = "https://${runpod_pod.comfyui_pod.id}-${var.comfyui_port}.proxy.runpod.net"
}

output "ssh_connection_command" {
  description = "Comando para conectar por SSH al contenedor en RunPod"
  value       = "ssh root@${runpod_pod.comfyui_pod.id}.proxy.runpod.net"
}

output "cloudflare_tunnel_instructions" {
  description = "Instrucciones para consultar la URL pública generada por Cloudflare Tunnel"
  value       = "Ejecuta por SSH o Web Terminal: cat /workspace/cloudflared.log | grep trycloudflare.com"
}
