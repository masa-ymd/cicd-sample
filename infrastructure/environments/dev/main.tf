terraform {
  # バックエンド設定
  backend "s3" {
    bucket = "cicd-sample-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"  # Terraform状態管理用S3バケットのリージョン
  }
}

module "infrastructure" {
  source = "../../"
  
  environment = "dev"
  project     = "cicd-sample"
  aws_region  = "ap-northeast-1"
} 