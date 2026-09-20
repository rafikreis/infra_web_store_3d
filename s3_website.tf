resource "aws_s3_bucket" "portfolio" {
  bucket = "terraform-infra-portfolio-rafik-2026"
}

resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "portfolio_public_access" {
  bucket = aws_s3_bucket.portfolio.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "portfolio_policy" {
  bucket     = aws_s3_bucket.portfolio.id
  depends_on = [aws_s3_bucket_public_access_block.portfolio_public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.portfolio.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.portfolio.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  
  etag         = filemd5("index.html") 
}

output "portfolio_website_url" {
  description = "The public URL of your S3 Portfolio Website"
  value       = "http://${aws_s3_bucket_website_configuration.portfolio_website.website_endpoint}"
}