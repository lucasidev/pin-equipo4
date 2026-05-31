output "server_public_ip" {
  description = "Public IP of the EC2 host running the stack."
  value       = aws_instance.pokedex_server.public_ip
}

output "api_url" {
  description = "Pokedex API on the EC2 host."
  value       = "http://${aws_instance.pokedex_server.public_ip}:3000/api"
}

output "ssh_command" {
  description = "SSH into the host (adjust the key path to your private key)."
  value       = "ssh ubuntu@${aws_instance.pokedex_server.public_ip}"
}
