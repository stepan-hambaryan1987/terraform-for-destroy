terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.46.0"
    }
  }

  backend "gcs" {
    bucket = "im-buckety-destroyi-terraformi-hamar"
    prefix = "terraform/state"
  }

}

provider "google" {
  project = "dev-project-467514"
  region  = "asia-northeast3"
}


