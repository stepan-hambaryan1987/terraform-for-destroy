# 1. Create VPC
resource "google_compute_network" "vpc_network" {
  name                    = "my-terraform-vpc"
  auto_create_subnetworks = false
}

# 2. Create Subnet
resource "google_compute_subnetwork" "pub_subnet" {
  name          = "my-terraform-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "asia-northeast3"
  network       = google_compute_network.vpc_network.id
}


# 3. Create Firewall Rule (allow SSH)
resource "google_compute_firewall" "my_firewall" {
  name    = "my-terraform-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}


# resource "google_compute_address" "my-external-ip" {
#   name   = "new-external-ip"
#   region = "asia-northeast3"
# }
variable "zones" {
  default = ["asia-northeast3-a", "asia-northeast3-b", "asia-northeast3-c"]
}

# 4. Create VM Instance
# resource "google_compute_instance" "vm_instance" {
#   count        = 1
#   name         = format("my-new-instance-%02d", count.index + 1) # my-instance-01 ... my-instance-10
#   machine_type = "e2-micro"
#   zone         = var.zones[count.index % length(var.zones)]

#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#     }
#   }

#   network_interface {
#     network    = google_compute_network.vpc_network.id
#     subnetwork = google_compute_subnetwork.pub_subnet.id

#     access_config {}
#   }

#   tags = ["ssh"]
#   metadata = {
#   startup-script = <<-EOT
#     #!/bin/bash
#     apt-get update
#     apt-get install -y nginx
#     systemctl enable nginx
#     systemctl start nginx

#     cat <<EOF > /var/www/html/index.html
#     <html>
#       <head>
#         <title>Welcome</title>
#       </head>
#       <body style="background-color: black; color: yellow; text-align: center; font-size: 24px; margin-top: 20%;">
#         barev im sireli Arevikin, es qez shat em sirum, du im hrashqn es $(hostname)
#       </body>
#     </html>
#     EOF
#   EOT
# }


# ============================
# 1. Instance Template
# ============================
resource "google_compute_instance_template" "vm_template" {
  name         = "my-instance-template"
  machine_type = "e2-micro"

  tags = ["ssh", "http"]

  disk {
    auto_delete  = true
    boot         = true
    source_image = "debian-cloud/debian-11"
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.pub_subnet.id

    access_config {} # External IP
  }

  metadata = {
  startup-script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx

    cat <<EOF > /var/www/html/index.html
    <html>
      <head>
        <title>Welcome</title>
      </head>
      <body style="background-color: cyan; color: yellow; text-align: center; font-size: 24px; margin-top: 20%;">
        barev im sireli Arevik, es qez shat em sirum, du im hrashqn es #$(hostname)
      </body>
    </html>
    EOF
  EOT
 }
}

# ============================
# 2. Managed Instance Group
# ============================
resource "google_compute_instance_group_manager" "vm_group" {
  name               = "my-instance-group"
  base_instance_name = "my-new-instance"
  zone               = var.zones[0]
  target_size        = 2

  auto_healing_policies {
    health_check      = google_compute_health_check.default.id
    initial_delay_sec = 300
  }

  version {
    instance_template = google_compute_instance_template.vm_template.id
  }

  named_port {
    name = "http"
    port = 80
  }
}


# ============================
# 3. Autoscaler
# ============================

resource "google_compute_autoscaler" "vm_group_autoscaler" {
  name   = "my-instance-autoscaler"
  zone   = var.zones[0]
  target = google_compute_instance_group_manager.vm_group.id

  autoscaling_policy {
    min_replicas = 2
    max_replicas = 5
    cpu_utilization {
      target = 0.6 # scale out when average CPU > 60%
    }
  }
}

# ============================
# 4. Health Check (for LB)
# ============================
resource "google_compute_health_check" "default" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

resource "time_sleep" "wait_for_healthcheck" {
  depends_on = [google_compute_health_check.default]
  create_duration = "20s"
}

# ============================
# 5. Backend Service 
# ============================
resource "google_compute_backend_service" "default" {
  name      = "backend-service"
  protocol  = "HTTP"
  port_name = "http"
  timeout_sec = 10
  health_checks = [google_compute_health_check.default.id]

  backend {
    group = google_compute_instance_group_manager.vm_group.instance_group
  }

  depends_on = [time_sleep.wait_for_healthcheck]
}


# ============================
# 6. URL Map LB
# ============================
resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = google_compute_backend_service.default.id
}

# ============================
# 7. HTTP Proxy
# ============================
resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy"
  url_map = google_compute_url_map.default.id
}

# ============================
# 8. Global Forwarding Rule
# ============================
resource "google_compute_global_forwarding_rule" "default" {
  name       = "http-forwarding-rule"
  port_range = "80"
  target     = google_compute_target_http_proxy.default.id
}

