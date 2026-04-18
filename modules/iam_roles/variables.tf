variable "project_name" { type = string }
variable "environment"  { type = string }
variable "s3_bucket_arn" { type = string }
variable "vended_role_arn" {
  type    = string
  default = "" # Populated after first apply via targeted apply pattern
}
