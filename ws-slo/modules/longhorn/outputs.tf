output "longhorn_backupstore" {
  value = {
    access_key_id     = var.longhorn_backupstore.access_key_id
    bucket            = aws_s3_bucket.longhorn_backups.bucket
    endpoint          = var.endpoints.s3
    region            = var.regions.aws_s3_bucket
    secret_access_key = var.longhorn_backupstore.secret_access_key
  }
  sensitive = true
}
