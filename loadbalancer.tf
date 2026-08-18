# One shared global external HTTPS load balancer (IP, cert, proxies, forwarding rules)
# in front of any number of Cloud Run services, host-routed by domain. Unlike the
# network/postgresql/redis modules, there's no create/consume split here: the URL map's
# host-routing rules and the certificate's domain list must be known in full at apply
# time, so exactly one caller owns this module and lists every app's domain in
# var.backends.
locals {
  backend_keys = { for domain, backend in var.backends : domain => replace(domain, ".", "-") }
  default_host = sort(keys(var.backends))[0]
}

resource "google_compute_region_network_endpoint_group" "this" {
  for_each = var.backends

  name                  = "${var.name}-${local.backend_keys[each.key]}-neg"
  project               = var.project_id
  region                = each.value.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = each.value.cloud_run_service
  }
}

resource "google_compute_backend_service" "this" {
  for_each = var.backends

  name                  = "${var.name}-${local.backend_keys[each.key]}-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.this[each.key].id
  }
}

resource "google_compute_managed_ssl_certificate" "this" {
  name    = "${var.name}-cert"
  project = var.project_id

  managed {
    domains = keys(var.backends)
  }
}

resource "google_compute_url_map" "this" {
  name            = "${var.name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.this[local.default_host].id

  dynamic "host_rule" {
    for_each = var.backends
    content {
      hosts        = [host_rule.key]
      path_matcher = local.backend_keys[host_rule.key]
    }
  }

  dynamic "path_matcher" {
    for_each = var.backends
    content {
      name            = local.backend_keys[path_matcher.key]
      default_service = google_compute_backend_service.this[path_matcher.key].id
    }
  }
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
}

resource "google_compute_global_address" "this" {
  name    = "${var.name}-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name}-https-fr"
  project               = var.project_id
  target                = google_compute_target_https_proxy.this.id
  port_range            = "443"
  ip_address            = google_compute_global_address.this.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_url_map" "http_redirect" {
  name    = "${var.name}-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "this" {
  name    = "${var.name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name}-http-fr"
  project               = var.project_id
  target                = google_compute_target_http_proxy.this.id
  port_range            = "80"
  ip_address            = google_compute_global_address.this.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
