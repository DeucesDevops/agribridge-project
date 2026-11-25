resource "aws_kms_key" "secrets" {
  description             = "AgriBridge application secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/agribridge-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}
