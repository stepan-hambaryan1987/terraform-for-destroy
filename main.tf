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
resource "google_compute_instance" "vm_instance" {
  count        = 1
  name         = format("my-new-instance-%02d", count.index + 1) # my-instance-01 ... my-instance-10
  machine_type = "e2-micro"
  zone         = var.zones[count.index % length(var.zones)]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.pub_subnet.id

    access_config {}
  }

  tags = ["ssh"]

  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      systemctl enable nginx
      systemctl start nginx
      echo "Hello from $(hostname)" > /var/www/html/index.html
    EOT
  }
}


