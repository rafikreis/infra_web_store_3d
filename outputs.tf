output "website_url" {
  description = "The public URL of the Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}