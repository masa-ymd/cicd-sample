terraform {
  # バックエンド設定
  backend "s3" {
    bucket = "cicd-sample-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"  # Terraform状態管理用S3バケットのリージョン
  }
}

# フロントエンドデプロイ用の変数
variable "frontend_version" {
  type    = string
  default = null
}

variable "frontend_build_path" {
  type    = string
  default = ""
}

# バックエンドデプロイ用の変数
variable "backend_version" {
  type    = string
  default = null
  description = "バックエンドのDockerイメージバージョン（ECRのタグ）。この値を設定することでデプロイするイメージを指定します。"
}

variable "backend_allowed_hosts" {
  type    = string
  default = "*"
  description = "バックエンドが受け付けるホスト名（カンマ区切り）。開発環境ではALBやCloudFrontのドメインを含めます。"
}

module "infrastructure" {
  source = "../../"
  
  environment = "dev"
  project     = "cicd-sample"
  aws_region  = "ap-northeast-1"
  
  # フロントエンドデプロイ用の変数を渡す
  frontend_version   = var.frontend_version
  frontend_build_path = var.frontend_build_path
  
  # バックエンドデプロイ用の変数を渡す
  backend_version     = var.backend_version
  backend_allowed_hosts = var.backend_allowed_hosts
} 