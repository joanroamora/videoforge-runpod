resource "runpod_pod" "comfyui_pod" {
  name                 = var.pod_name
  image_name           = var.container_image
  gpu_type_id          = var.gpu_type_id
  cloud_type           = var.cloud_type
  gpu_count            = var.gpu_count
  container_disk_in_gb = var.container_disk_size
  volume_in_gb         = var.volume_size
  volume_mount_path    = var.volume_mount_path
  ports                = "${var.comfyui_port}/http,22/tcp"

  env = [
    "PUBLIC_KEY=${var.public_key}"
  ]

  # Inyección y ejecución del script de inicio automatizado al arrancar el Pod
  docker_args = "bash -c 'echo \"${base64encode(file("${path.module}/scripts/startup.sh"))}\" | base64 -d > /tmp/startup.sh && chmod +x /tmp/startup.sh && /tmp/startup.sh'"
}
