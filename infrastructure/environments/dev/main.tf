module "infrastructure" {
  source = "../../"
  
  environment = "dev"
  project     = "cicd-sample"
  aws_region  = "us-east-1"
} 