output "servidor_ip_publica" {
  # Asegúrate de que "pokedex_server" o "nuxt_server" coincida con tu ec2.tf
  value       = aws_instance.pokedex_server.public_ip
  description = "IP pública de tu servidor para acceder a la Pokedex API"
}

output "ssh_conexion" {
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.nuxt_server.public_ip}"
  description = "Comando rapido para conectarte a tu servidor por SSH"
}
