# 1. Obtener la AMI de Ubuntu LTS más reciente
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# 2. Configurar par de llaves SSH de forma dinámica
resource "aws_key_pair" "deployer" {
  key_name   = "${var.proyecto_nombre}-key"
  public_key = var.ssh_public_key # file("~/.ssh/id_rsa.pub")
}

# 3. Crear la instancia EC2 configurada para Docker y Just
resource "aws_instance" "pokedex_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instancia_tipo
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # Script de automatización DevSecOps para entornos Dockerificados
  user_data = <<-EOF
              #!/bin/bash
              # Evitar interrupciones de prompts interactivos en Ubuntu
              export DEBIAN_FRONTEND=noninteractive

              # Actualizar sistema e instalar pre-requisitos
              sudo apt-get update -y
              sudo apt-get install -y curl git apt-transport-https ca-certificates gnupg lsb-release

              # ==========================================
              # INSTALACIÓN OFICIAL DE DOCKER & COMPOSE
              # ==========================================
              sudo mkdir -p /etc/apt/keyrings
              curl -fsSL https://docker.com | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://docker.com $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.p/docker.list > /dev/null
              
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

              # Configurar permisos para ejecutar docker sin sudo
              sudo usermod -aG docker ubuntu

              # ==========================================
              # INSTALACIÓN DE JUST (Runner de tareas)
              # ==========================================
              # Descargar el instalador oficial de Just y agregarlo a binarios globales
              curl --proto '=https' --tlsv1.2 -sSf https://just.systems | sudo bash -s -- --to /usr/local/bin

              # ==========================================
              # PREPARACIÓN DEL ENTORNO DE LA APLICACIÓN
              # ==========================================
              mkdir -p /home/ubuntu/app
              chown -R ubuntu:ubuntu /home/ubuntu/app

              # Nota de Arquitectura: La imagen 'pokedex-api' requiere Mongo y Redis.
              # Creamos un docker-compose base automatizado para que el semillero no falle.
              cat << 'INNER_EOF' > /home/ubuntu/app/docker-compose.yml
              version: '3.8'

              services:
                mongodb:
                  image: mongo:latest
                  ports:
                    - "27017:27017"
                  volumes:
                    - mongo_data:/data/db

                redis:
                  image: redis:alpine
                  ports:
                    - "6379:6379"

                pokedex-api:
                  image: ghcr.io/lucasidev/pokedex-api:sha256-6a07f1d8597f2521853d949ac2a757b5ebf79dcce35b56aa7c4136802b4bc4a1.sig
                  ports:
                    - "3000:3000"
                  environment:
                    - MONGODB_URI=mongodb://mongodb:27017/pokedex
                    - REDIS_URL=redis://redis:6379
                  depends_on:
                    - mongodb
                    - redis
              
              volumes:
                mongo_data:
              INNER_EOF

              chown ubuntu:ubuntu /home/ubuntu/app/docker-compose.yml
              EOF

  tags = { Name = "${var.proyecto_nombre}-server" }
}
