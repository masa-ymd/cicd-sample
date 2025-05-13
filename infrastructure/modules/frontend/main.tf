# フロントエンドインフラストラクチャ: S3 + CloudFront
variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "api_endpoint" {
  type = string
  description = "Backend API endpoint URL"
}

# フロントエンドのデプロイで使用する変数
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

# フロントエンド資産用のS3バケット
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend-${var.environment}"

  tags = {
    Name        = "${var.project}-frontend-${var.environment}"
    Environment = var.environment
  }
}

# S3バケットのバージョニング有効化（バージョン管理用）
resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFrontログ用のS3バケット
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.project}-cf-logs-${var.environment}"

  tags = {
    Name        = "${var.project}-cf-logs-${var.environment}"
    Environment = var.environment
  }
}

# CloudFrontログバケットのオブジェクト所有権設定（ACLを有効化）
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# CloudFrontログバケットのACL設定
resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
  
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"
}

# CloudFront用のOrigin Access Identity（OAI）
# S3へのアクセスをCloudFrontに限定するための設定
resource "aws_cloudfront_origin_access_identity" "frontend_oai" {
  comment = "OAI for ${var.project} frontend ${var.environment}"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.frontend.id
    origin_path = "/current"  # currentディレクトリを参照するように設定
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend_oai.cloudfront_access_identity_path
    }
  }
  
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "cloudfront-logs/"
  }
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.frontend.id
    
    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  # Handle SPA routing
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
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
    Name        = "${var.project}-frontend-${var.environment}"
    Environment = var.environment
  }
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend_oai.iam_arn
        }
      }
    ]
  })
}

# 通常デプロイ用 - ビルドフォルダからS3へのアップロード
resource "null_resource" "upload_to_s3" {
  # ビルドパスが指定されていて、バージョンも指定されている場合のみ実行
  count = var.frontend_build_path != "" && var.frontend_version != null ? 1 : 0

  triggers = {
    version = var.frontend_version
  }

  provisioner "local-exec" {
    command = <<EOT
      # ビルドファイルをS3にアップロード
      aws s3 sync ${var.frontend_build_path}/ s3://${aws_s3_bucket.frontend.bucket}/${var.frontend_version}/ --delete
      
      # カレントディレクトリにコピー（CloudFrontから参照される）
      aws s3 sync s3://${aws_s3_bucket.frontend.bucket}/${var.frontend_version}/ s3://${aws_s3_bucket.frontend.bucket}/current/ --delete
      
      # バージョン情報ファイルを作成
      echo "{\"version\": \"${var.frontend_version}\", \"deploy_date\": \"$(date --iso-8601=seconds)\"}" > /tmp/version.json
      aws s3 cp /tmp/version.json s3://${aws_s3_bucket.frontend.bucket}/current/version.json --metadata-directive REPLACE
      
      # CloudFrontのキャッシュを無効化
      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths "/*"
    EOT
  }

  depends_on = [
    aws_s3_bucket.frontend,
    aws_cloudfront_distribution.frontend,
    aws_s3_bucket_policy.frontend
  ]
}

# ロールバック用 - 既存のバージョンディレクトリからcurrentへのコピー
resource "null_resource" "rollback_to_version" {
  # ビルドパスが空で、バージョンが明示的に指定されている場合のみ実行
  count = var.frontend_build_path == "" && var.frontend_version != null ? 1 : 0

  triggers = {
    version = var.frontend_version
  }

  provisioner "local-exec" {
    command = <<EOT
      # 指定されたバージョンディレクトリの存在確認
      if ! aws s3 ls "s3://${aws_s3_bucket.frontend.bucket}/${var.frontend_version}/" --delimiter "/" 2>/dev/null; then
        echo "エラー: 指定されたバージョン ${var.frontend_version} はS3バケットに存在しません"
        exit 1
      fi
      
      # 指定されたバージョンからcurrentへコピー（ロールバック）
      aws s3 sync s3://${aws_s3_bucket.frontend.bucket}/${var.frontend_version}/ s3://${aws_s3_bucket.frontend.bucket}/current/ --delete
      
      # バージョン情報ファイルを作成
      echo "{\"version\": \"${var.frontend_version}\", \"rollback_date\": \"$(date --iso-8601=seconds)\", \"rollback_by\": \"terraform\"}" > /tmp/version.json
      aws s3 cp /tmp/version.json s3://${aws_s3_bucket.frontend.bucket}/current/version.json --metadata-directive REPLACE
      
      # CloudFrontのキャッシュを無効化
      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths "/*"
      
      echo "✅ フロントエンドを ${var.frontend_version} バージョンにロールバックしました"
    EOT
  }

  depends_on = [
    aws_s3_bucket.frontend,
    aws_cloudfront_distribution.frontend,
    aws_s3_bucket_policy.frontend
  ]
}

# Output CloudFront URL
output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
} 