terraform {
  required_version = ">= 1.5.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = ">= 0.62.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}
