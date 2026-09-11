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
  description = "Map of domain -> backend to route to, keyed by the public hostname (e.g. \"crm.example.com\"). Every domain listed here is added to the shared managed SSL certificate and given a host-based routing rule. Each entry is either: (a) cloud_run_service + region, and this module creates the regional serverless NEG + backend service itself; or (b) backend_service_id, an already-created backend service owned and managed elsewhere (e.g. by the app's own repo/state) -- this module only references it in the URL map, it doesn't create or destroy it. Exactly one of the two forms must be set per entry."
  type = map(object({
    cloud_run_service  = optional(string)
    region             = optional(string)
    backend_service_id = optional(string)
  }))

  validation {
    condition = alltrue([
      for b in var.backends :
      (b.backend_service_id != null) != (b.cloud_run_service != null && b.region != null)
    ])
    error_message = "Each backend must set either backend_service_id, or both cloud_run_service and region, but not both/neither."
  }
}
