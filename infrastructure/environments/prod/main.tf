module "infrastructure" {
  source = "../../"
  
  environment = "prod"
  project     = "cicd-sample"
  aws_region  = "us-east-1"
} 