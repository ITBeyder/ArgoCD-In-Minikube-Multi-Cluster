terraform {
  required_providers {
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.2"
    }
  }
}

provider "argocd" {
use_local_config = true
}
