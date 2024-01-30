terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0"
    }
    static = {
      source  = "tiwood/static"
      version = ">= 0.1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.10.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
