variable "region" {
    default = "us-east-1"
}

variable "docker_image_url" {
    description = "The URL of the Docker image"
    type        = string
}
