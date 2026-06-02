# Latest Ubuntu 22.04 LTS AMI from Canonical.
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

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# Bootstraps Docker and brings up the stack via user_data. The compose file
# written here mirrors compose/docker-compose.yml: mongo + redis with auth,
# and the api wired with the full env it requires at boot (JWT, admin seed,
# connection strings). Secrets come from terraform variables, not hardcoded.
resource "aws_instance" "pokedex_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # Intentional: this is a public demo host. HTTP (80) and the API (3000)
  # are reachable from the internet via the security group; SSH stays
  # limited to var.admin_cidr. Declared explicitly so the public exposure
  # is a reviewed decision, not an implicit default.
  associate_public_ip_address = true

  # The image tag is baked into user_data, which only runs on first boot.
  # Recreate the instance when user_data changes (i.e. when api_image points
  # at a new immutable tag), so a new image is actually rolled out. Trade-off:
  # a new deploy means a fresh instance (brief downtime, new public IP),
  # acceptable for a demo host. See ADR 0004.
  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              export DEBIAN_FRONTEND=noninteractive

              apt-get update -y
              apt-get install -y ca-certificates curl gnupg

              # Official Docker repository + engine with the compose plugin.
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              usermod -aG docker ubuntu

              mkdir -p /home/ubuntu/app
              cat > /home/ubuntu/app/docker-compose.yml <<'INNER_EOF'
              name: pokedex
              services:
                mongo:
                  image: mongo:7
                  restart: unless-stopped
                  environment:
                    MONGO_INITDB_ROOT_USERNAME: ${var.mongo_root_user}
                    MONGO_INITDB_ROOT_PASSWORD: ${var.mongo_root_password}
                    MONGO_INITDB_DATABASE: pokedex
                  volumes:
                    - mongo_data:/data/db

                redis:
                  image: redis:7-alpine
                  restart: unless-stopped
                  command: ["redis-server", "--requirepass", "${var.redis_password}"]

                api:
                  image: ${var.api_image}
                  restart: unless-stopped
                  depends_on:
                    - mongo
                    - redis
                  environment:
                    NODE_ENV: production
                    PORT: "3000"
                    MONGODB_URI: mongodb://${var.mongo_root_user}:${var.mongo_root_password}@mongo:27017/pokedex?authSource=admin
                    REDIS_URL: redis://:${var.redis_password}@redis:6379
                    JWT_SECRET: ${var.jwt_secret}
                    JWT_EXPIRES_IN: 1h
                    ADMIN_EMAIL: ${var.admin_email}
                    ADMIN_PASSWORD: ${var.admin_password}
                    CORS_ORIGIN: http://localhost:3000
                  ports:
                    - "3000:3000"

              volumes:
                mongo_data:
              INNER_EOF

              chown -R ubuntu:ubuntu /home/ubuntu/app
              cd /home/ubuntu/app && docker compose up -d
              EOF

  tags = { Name = "${var.project_name}-server" }
}
