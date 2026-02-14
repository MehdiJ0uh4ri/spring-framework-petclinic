output "app_url" {
  value = "http://localhost:${docker_container.app.ports[0].external}"
}

output "app_container_id" {
  value = docker_container.app.id
}

output "mysql_container_id" {
  value = docker_container.mysql.id
}

output "mysql_host" {
  value = docker_container.mysql.name
}

output "connection_info_file" {
  value = local_file.connection_info.filename
}