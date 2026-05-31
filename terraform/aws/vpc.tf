# Crear la VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "${var.proyecto_nombre}-vpc" }
}

# Crear la Subred Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Asigna IP pública automáticamente
  tags                    = { Name = "${var.proyecto_nombre}-public-subnet" }
}

# Internet Gateway para conectar la VPC a internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.proyecto_nombre}-igw" }
}

# Tabla de Enrutamiento para la subred pública
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Grupo de Seguridad (Firewall)
resource "aws_security_group" "web_sg" {
  name        = "${var.proyecto_nombre}-web-sg"
  description = "Permitir trafico HTTP, HTTPS, Nuxt y SSH"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nuxt.js App Port
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (Por seguridad en producción deberías limitarlo a tu IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tráfico de salida permitido hacia cualquier lugar (Para descargar Node.js, npm, etc)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
