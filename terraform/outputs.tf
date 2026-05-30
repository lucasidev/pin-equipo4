output "servidor_ip_publica" {
  value       = aws_instance.nuxt_server.public_ip
  description = "IP publica de tu servidor para desplegar tu app Nuxt"
}

output "ssh_conexion" {
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.nuxt_server.public_ip}"
  description = "Comando rapido para conectarte a tu servidor por SSH"
}
