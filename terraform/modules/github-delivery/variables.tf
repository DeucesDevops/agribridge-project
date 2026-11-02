variable "region" { type = string }
variable "account_id" { type = string }
variable "environments" { type = set(string) }
variable "repository_subject_prefix" { type = string }
variable "parameter_arns" { type = list(string) }
