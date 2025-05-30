terraform {
  # バックエンド設定
  backend "s3" {
    bucket = "cicd-sample-terraform-state"
    key    = "prod/terraform.tfstate"
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
  description = "バックエンドのDockerイメージバージョン（ECRのタグ）。本番環境では通常 v1.2.3 形式のセマンティックバージョンを指定します。"
}

variable "backend_allowed_hosts" {
  type    = string
  default = "*"
  description = "バックエンドが受け付けるホスト名（カンマ区切り）。本番環境では本番用ドメインやALB、CloudFrontのドメインを含めます。"
}

module "infrastructure" {
  source = "../../"
  
  environment = "prod"
  project     = "cicd-sample"
  aws_region  = "ap-northeast-1"
  
  # フロントエンドデプロイ用の変数を渡す
  frontend_version   = var.frontend_version
  frontend_build_path = var.frontend_build_path
  
  # バックエンドデプロイ用の変数を渡す
  backend_version     = var.backend_version
  backend_allowed_hosts = var.backend_allowed_hosts
} 