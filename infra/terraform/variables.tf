variable "region" { default = "ap-southeast-1" }
variable "project_prefix" { default = "inf2006-minimal" }
variable "firehose_buffer_size" { default = 5 }     # MiB
variable "firehose_buffer_interval" { default = 60 } # sec
variable "tags" { type = map(string) default = { Project = "INF2006", Env = "dev" } }
