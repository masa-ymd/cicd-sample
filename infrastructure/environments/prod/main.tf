terraform {
  # バックエンド設定
  backend "s3" {
    bucket = "cicd-sample-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"  # Terraform状態管理用S3バケットのリージョン
  }
}

module "infrastructure" {
  source = "../../"
  
  environment = "prod"
  project     = "cicd-sample"
  aws_region  = "ap-northeast-1"
} 