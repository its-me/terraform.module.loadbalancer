output "ip_address" {
  description = "Global external IP of the load balancer. Point an A record for every domain in var.backends at this."
  value       = google_compute_global_address.this.address
}

output "backend_service_ids" {
  description = "Map of domain -> backend service ID."
  value       = { for domain, backend in google_compute_backend_service.this : domain => backend.id }
}

output "certificate_id" {
  description = "ID of the shared managed SSL certificate."
  value       = google_compute_managed_ssl_certificate.this.id
}
