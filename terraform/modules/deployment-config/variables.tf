variable "environments" { type = set(string) }
variable "region" { type = string }
variable "zone_name" { type = string }
variable "repositories" { type = map(string) }
variable "secret_arns" { type = map(string) }
variable "backup_bucket" { type = string }
variable "backup_roles" { type = map(string) }
