variable "folder_id" {
  type        = string
  description = "ID каталога в Yandex Cloud"
  sensitive = true
}

variable "ssh_key_path" {
  type        = string
  description = "Путь к публичному SSH-ключу"
  sensitive = true
}