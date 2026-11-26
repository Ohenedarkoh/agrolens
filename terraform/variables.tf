# Existing default VPC where the AgroLens Redshift workgroup will be deployed.
variable "vpc_id" {
  description = "VPC used by the AgroLens Redshift workgroup"
  type        = string
  default     = "vpc-0e3f69478e29d8dc7"
}

# Three subnets in separate Availability Zones.
# Redshift Serverless requires subnets spanning at least three Availability Zones.
variable "subnet_ids" {
  description = "Subnets across three Availability Zones"
  type        = list(string)

  default = [
    "subnet-097f369bbba8e9170",
    "subnet-0116635fb32eb14ae",
    "subnet-0f55c36177afd4cf4"
  ]
}

# Restricts inbound Redshift connections to your current public IP.
# /32 means only this specific IPv4 address is allowed.
variable "allowed_client_cidr" {
  description = "Public IP allowed to connect to Redshift"
  type        = string
  default     = "154.161.44.219/32"
}



