variable "project_id" {
  description = "GCP project ID the load balancer lives in."
  type        = string
}

variable "name" {
  description = "Name prefix for the load balancer's resources (IP, proxies, forwarding rules, cert)."
  type        = string
  default     = "apps"
}

variable "backends" {
  description = "Map of domain -> Cloud Run service to route to, keyed by the public hostname (e.g. \"crm.example.com\"). Every domain listed here is added to the shared managed SSL certificate and given a host-based routing rule."
  type = map(object({
    cloud_run_service = string
    region            = string
  }))
}
