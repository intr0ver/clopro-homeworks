output "public_vm_public_ip" {
  value       = yandex_compute_instance.public_test_vm.network_interface[0].nat_ip_address
  description = "Публичный IP публичной тестовой ВМ (jump host)"
}

output "nat_instance_public_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].nat_ip_address
  description = "Публичный IP NAT-инстанса"
}

output "nat_instance_internal_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].ip_address
  description = "Внутренний IP NAT-инстанса (должен быть 192.168.10.254)"
}

output "private_vm_internal_ip" {
  value       = yandex_compute_instance.private_test_vm.network_interface[0].ip_address
  description = "Внутренний IP приватной тестовой ВМ"
}