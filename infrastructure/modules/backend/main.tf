# Backend Infrastructure: ECS, ECR, ALB
variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "container_cpu" {
  type    = number
  default = 256
}

variable "container_memory" {
  type    = number
  default = 512
}

# バックエンドデプロイ用の変数を追加
variable "backend_version" {
  type        = string
  default     = null
  description = "バックエンドのデプロイバージョン - ECRリポジトリのイメージタグを指定します。この値を変更することでデプロイされるDockerイメージのバージョンが変わります。"
}

variable "backend_allowed_hosts" {
  type        = string
  default     = "*"
  description = "バックエンドの許可されたホスト - Railsアプリケーションがリクエストを受け付けるホスト名をカンマ区切りで指定します。"
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "backend" {
  name = "${var.project}-backend-${var.environment}"
  
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = "${var.project}-backend-${var.environment}"
    Environment = var.environment
  }
}

# VPC for ECS Fargate
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name        = "${var.project}-vpc-${var.environment}"
    Environment = var.environment
  }
}

# Create public subnets in different AZs
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = "ap-northeast-1${count.index == 0 ? "a" : "c"}"
  
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.project}-public-subnet-${count.index + 1}-${var.environment}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project}-igw-${var.environment}"
    Environment = var.environment
  }
}

# Route Table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.project}-public-rt-${var.environment}"
    Environment = var.environment
  }
}

# Route Table Association for public subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg-${var.environment}"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.project}-alb-sg-${var.environment}"
    Environment = var.environment
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg-${var.environment}"
  description = "Security group for ECS"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.project}-ecs-sg-${var.environment}"
    Environment = var.environment
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.project}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  tags = {
    Name        = "${var.project}-alb-${var.environment}"
    Environment = var.environment
  }
}

# ALB Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.project}-tg-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    path                = "/api/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
  
  tags = {
    Name        = "${var.project}-tg-${var.environment}"
    Environment = var.environment
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster-${var.environment}"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name        = "${var.project}-cluster-${var.environment}"
    Environment = var.environment
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-ecs-execution-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "${var.project}-ecs-execution-role-${var.environment}"
    Environment = var.environment
  }
}

# Attach ECS Task Execution Policy
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  
  # コンテナ定義 - Dockerイメージのバージョンを変更するには backend_version 変数を設定します
  # 例: terraform apply -var='backend_version=v1.2.3'
  # または deploy.auto.tfvars ファイルに backend_version = "v1.2.3" を設定
  container_definitions = jsonencode([
    {
      name      = "${var.project}-container-${var.environment}"
      # イメージバージョンの設定 - backend_version 変数で制御されます
      image     = var.backend_version != null ? "${aws_ecr_repository.backend.repository_url}:${var.backend_version}" : "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "RAILS_ENV"
          value = var.environment == "prod" ? "production" : "development"
        },
        {
          name  = "CORS_ORIGINS"
          value = "*" # In a real application, this should be restricted
        },
        # アプリケーションバージョン - backend_version 変数から自動設定されます
        {
          name  = "APP_VERSION"
          value = var.backend_version != null ? var.backend_version : var.environment == "prod" ? "v1.0.0" : "dev"
        },
        {
          name  = "ALLOWED_HOSTS"
          value = var.backend_allowed_hosts
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  
  tags = {
    Name        = "${var.project}-task-${var.environment}"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name        = "${var.project}-logs-${var.environment}"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.project}-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 0
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.project}-container-${var.environment}"
    container_port   = var.container_port
  }
  
  depends_on = [
    aws_lb_listener.http
  ]
  
  # Terraformによるデプロイを可能にするため、task_definitionの変更を監視するように修正
  lifecycle {
    ignore_changes = [
      desired_count     # オートスケーリングや運用時の手動調整を許可
    ]
  }
  
  tags = {
    Name        = "${var.project}-service-${var.environment}"
    Environment = var.environment
  }
}

# Output the API endpoint
output "api_endpoint" {
  value = "http://${aws_lb.main.dns_name}"
}

# CloudFront distribution for ALB
resource "aws_cloudfront_distribution" "api" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  http_version        = "http2"
  
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb"
    
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["*"]
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name        = "${var.project}-api-cf-${var.environment}"
    Environment = var.environment
  }
}

# Output CloudFront API endpoint
output "api_cloudfront_endpoint" {
  value = "https://${aws_cloudfront_distribution.api.domain_name}"
}

# フロントエンド同様、バックエンドのデプロイ完了後にCloudFront Invalidationを実行
resource "null_resource" "invalidate_cloudfront_cache" {
  count = var.backend_version != null ? 1 : 0

  triggers = {
    version = var.backend_version
  }

  provisioner "local-exec" {
    command = <<EOT
      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.api.id} --paths "/*"
      echo "✅ バックエンドAPI: CloudFrontキャッシュを無効化しました"
    EOT
  }

  depends_on = [
    aws_ecs_service.main
  ]
} 