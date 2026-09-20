terraform{
    backend "s3" {
        bucket = "web-3d-terraform-state-2026"
        key = "web-3d/terraform.tfstate"
        region = "us-east-1"
        use_lockfile = true
        encrypt= true 
    }
}