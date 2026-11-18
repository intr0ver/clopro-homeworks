terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }
}

provider "yandex" {
  folder_id = var.folder_id
  zone      = "ru-central1-a"
  # YC_TOKEN и YC_CLOUD_ID подхватываются из переменных окружения
}

locals {
  network_name    = "hw-network"
  public_subnet   = "public"
  private_subnet  = "private"
  nat_instance_ip = "192.168.10.254"
  image_id        = "fd80mrhj8fl2oe87o4e1" # образ из задания (NAT-instance / Ubuntu)
  disk_size       = 10
  disk_type       = "network-hdd"
  zone            = "ru-central1-a"
}

# ---------- 1. VPC ----------
resource "yandex_vpc_network" "hw_network" {
  name = local.network_name
}

# ---------- 2. Публичная подсеть ----------
resource "yandex_vpc_subnet" "public_subnet" {
  name           = local.public_subnet
  zone           = local.zone
  network_id     = yandex_vpc_network.hw_network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# ---------- 3. Группа безопасности ----------
resource "yandex_vpc_security_group" "nat_sg" {
  name       = "nat-instance-sg"
  network_id = yandex_vpc_network.hw_network.id

  egress {
    protocol       = "ANY"
    description    = "any outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  
  ingress {
  protocol       = "ICMP"
  description    = "allow ICMP from private subnet"
  v4_cidr_blocks = ["192.168.20.0/24"]
}
}

# ---------- 4. NAT-инстанс ----------
# ВНИМАНИЕ: preemptible = true — NAT может быть остановлен облаком,
# и тогда у приватной ВМ пропадёт интернет.
# Для учебного задания допустимо; для стабильного NAT поставьте false.
resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = local.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
      size     = local.disk_size
      type     = local.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_subnet.id
    nat                = true
    ip_address         = local.nat_instance_ip
    security_group_ids = [yandex_vpc_security_group.nat_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

# ---------- 5. Публичная тестовая ВМ (jump host) ----------
resource "yandex_compute_instance" "public_test_vm" {
  name        = "public-test-vm"
  platform_id = "standard-v3"
  zone        = local.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
      size     = local.disk_size
      type     = local.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nat_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

# ---------- 6. Таблица маршрутизации ----------
resource "yandex_vpc_route_table" "private_route_table" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.hw_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface[0].ip_address
  }
}

# ---------- 7. Приватная подсеть с маршрутом через NAT ----------
resource "yandex_vpc_subnet" "private_subnet" {
  name           = local.private_subnet
  zone           = local.zone
  network_id     = yandex_vpc_network.hw_network.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

# ---------- 8. Приватная тестовая ВМ ----------
resource "yandex_compute_instance" "private_test_vm" {
  name        = "private-test-vm"
  platform_id = "standard-v3"
  zone        = local.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
      size     = local.disk_size
      type     = local.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_subnet.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.nat_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}