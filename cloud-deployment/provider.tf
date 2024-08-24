provider "aws" {
  alias = "ca-central-1"
  region = "ca-central-1"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}