terraform {
  # 必要なプロバイダーの設定
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Terraformの状態管理をS3で行う設定
  backend "s3" {
    bucket = "cicd-sample-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

# AWSプロバイダーの設定
provider "aws" {
  region = var.aws_region
}

# 共通変数の定義
# AWSリージョン
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# 環境（dev または prod）
variable "environment" {
  type    = string
  description = "Environment (dev or prod)"
}

# プロジェクト名
variable "project" {
  type    = string
  default = "cicd-sample"
}

# 環境特有のモジュールのインポート
# フロントエンドモジュール
module "frontend" {
  source = "./modules/frontend"
  
  environment = var.environment
  project     = var.project
  api_endpoint = module.backend.api_endpoint
}

# バックエンドモジュール
module "backend" {
  source = "./modules/backend"
  
  environment = var.environment
  project     = var.project
}

# 出力値の定義
# フロントエンドのURL出力
output "frontend_url" {
  value = module.frontend.cloudfront_url
}

# バックエンドAPIのURL出力
output "backend_url" {
  value = module.backend.api_endpoint
} 