resource "random_id" "longhorn_backups" {
  byte_length = 4
  prefix      = "${var.project}-${var.name}-longhorn-backups-"
}

resource "aws_s3_bucket" "longhorn_backups" {
  bucket = random_id.longhorn_backups.hex
}
