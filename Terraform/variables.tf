variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "LambdaFunctionName" {
  type    = string
  default = "Dormant_S3_Buckets-LambdaFunction"
}

variable "Email" {
  type = string
}

variable "S3PathAthenaQuery" {
  type        = string
  description = "The S3 URI e.g. s3://athena-query-information/s3-access-logs-last-accessed-queries/"

  validation {
    condition     = substr(var.S3PathAthenaQuery, -1, 1) == "/" && substr(var.S3PathAthenaQuery, 0, 5) == "s3://"
    error_message = "The S3 URI must start with \"s3://\" and end with \"/\"."
  }
}

variable "Limit" {
  type        = number
  default     = 10
  description = "The number of days before flagging the S3 bucket out."
}

variable "Query" {
  type    = string
  default = "SELECT bucket_name, MAX(parse_datetime(requestdatetime,'dd/MMM/yyyy:HH:mm:ss Z')) AS last_accessed_date FROM s3_access_logs_db.mybucket_logs WHERE NOT key='-' GROUP BY bucket_name;"
}
