terraform {
  # 必要なプロバイダーの設定
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # バックエンド設定は環境ごとのディレクトリに移動
}

# AWSプロバイダーの設定
provider "aws" {
  region = var.aws_region
}

# 共通変数の定義
# AWSリージョン - 東京リージョンをデフォルトに変更
variable "aws_region" {
  type    = string
  default = "ap-northeast-1"  # 東京リージョン
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

# フロントエンドデプロイ用の変数
variable "frontend_version" {
  type    = string
  default = null
  description = "フロントエンドのデプロイバージョン"
}

variable "frontend_build_path" {
  type    = string
  default = ""
  description = "フロントエンドのビルドディレクトリへのパス"
}

# バックエンドデプロイ用の変数
variable "backend_version" {
  type    = string
  default = null
  description = "バックエンドのデプロイバージョン - ECRイメージのタグを指定します。このパラメータを設定することで、ECSタスク定義で使用されるDockerイメージが変更されます。"
}

variable "backend_allowed_hosts" {
  type    = string
  default = "*"
  description = "バックエンドの許可されたホスト - Railsアプリケーションが許可するホスト名のリスト（カンマ区切り）。"
}

# 環境特有のモジュールのインポート
# フロントエンドモジュール
module "frontend" {
  source = "./modules/frontend"
  
  environment = var.environment
  project     = var.project
  api_endpoint = module.backend.api_endpoint
  
  # フロントエンドデプロイ用の変数
  frontend_version   = var.frontend_version
  frontend_build_path = var.frontend_build_path
}

# バックエンドモジュール
module "backend" {
  source = "./modules/backend"
  
  environment = var.environment
  project     = var.project
  
  # バックエンドデプロイ用の変数
  backend_version      = var.backend_version
  backend_allowed_hosts = var.backend_allowed_hosts
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