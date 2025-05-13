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

module "infrastructure" {
  source = "../../"
  
  environment = "dev"
  project     = "cicd-sample"
  aws_region  = "ap-northeast-1"
  
  # フロントエンドデプロイ用の変数を渡す
  frontend_version   = var.frontend_version
  frontend_build_path = var.frontend_build_path
} 