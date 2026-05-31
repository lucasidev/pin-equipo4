variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "proyecto_nombre" {
  type    = string
  default = "semillero-nuxt-app"
}

variable "instancia_tipo" {
  type    = string
  default = "t3.micro" # Económica y suficiente para prácticas
}
