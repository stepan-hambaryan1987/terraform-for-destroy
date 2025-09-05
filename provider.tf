terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.46.0"
    }
  }
}

provider "google" {
  project = "dev-project-467514"
  region  = "asia-northeast3"
}


