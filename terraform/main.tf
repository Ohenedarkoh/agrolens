#provider-connect terraform to aws
#resource - an infrastructure component eg s3 bucket
#variable - a configurable value
#output - information terraform returns after deployment
#state - terraforms record of managed infrastructure
#plan - shows what terraform intends to change
#apply - executes the proposed changes

# init - prepare the dir for other commands
# validate - check whether configuration is valid
# plan - show changes before execution
# apply - create or update infrastructure
# destroy - delete infrastructure

resource "aws_s3_bucket" "data_lake" {
  bucket = "agrolens-data-lake-254212223627"
}


#block public access
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


#enable versioning
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}



# Security group controlling network access to the Redshift workgroup.
resource "aws_security_group" "redshift" {
  name        = "agrolens-redshift-sg"
  description = "Allows Redshift access from the approved client IP"
  vpc_id      = var.vpc_id

  # Allow connections to Redshift only from the approved public IP.
  ingress {
    description = "Redshift access from approved client IP"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.allowed_client_cidr]
  }

  # Allow outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "agrolens-redshift-sg"
    Project     = "AgroLens"
    Environment = "Development"
  }
}




# Redshift Serverless namespace containing the AgroLens data warehouse.
resource "aws_redshiftserverless_namespace" "agrolens" {
  namespace_name = "agrolens"
  db_name        = "agrolens"
  admin_username = "agrolens_admin"

  # Allow AWS to generate and manage the administrator password.
  manage_admin_password = true


  # Associate the dedicated S3 access role with this namespace.
  iam_roles = [aws_iam_role.redshift_s3_access.arn]

  # Make this role the default for Redshift S3 operations.
  default_iam_role_arn = aws_iam_role.redshift_s3_access.arn


  # Encrypt data at rest using AWS-managed encryption.
  tags = {
    Name        = "agrolens-namespace"
    Project     = "AgroLens"
    Environment = "Development"

  }
}


# Compute environment for the AgroLens Redshift Serverless data warehouse.
resource "aws_redshiftserverless_workgroup" "agrolens" {
  workgroup_name = "agrolens-workgroup"
  namespace_name = aws_redshiftserverless_namespace.agrolens.namespace_name

  # Starting compute capacity, measured in Redshift Processing Units (RPUs).
  base_capacity = 4

  # Maximum compute capacity allowed for this workgroup.
  max_capacity = 4

  # Default Redshift connection port.
  port = 5439

  # Allow connections over the public internet.
  # The security group still restricts access to our approved IP.
  publicly_accessible = true

  # Use the existing subnets across three Availability Zones.
  subnet_ids = var.subnet_ids

  # Attach the security group created earlier.
  security_group_ids = [aws_security_group.redshift.id]

  tags = {
    Name        = "agrolens-workgroup"
    Project     = "AgroLens"
    Environment = "Development"
  }
}




# Monthly compute usage limit for the AgroLens Redshift workgroup.
resource "aws_redshiftserverless_usage_limit" "agrolens" {
  # Apply the limit to our Redshift Serverless workgroup.
  resource_arn = aws_redshiftserverless_workgroup.agrolens.arn

  # Monitor compute consumption measured in RPU-hours.
  usage_type = "serverless-compute"

  # Maximum monthly compute consumption.
  amount = 20

  # Deactivate the workgroup when the usage limit is reached.
  breach_action = "deactivate"

  # Reset the usage limit monthly.
  period = "monthly"
}





# Monthly AWS cost budget for monitoring AgroLens infrastructure spending.
resource "aws_budgets_budget" "agrolens" {
  name         = "agrolens-monthly-budget"
  budget_type  = "COST"
  limit_amount = "15"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alert when actual monthly spending reaches 50% of the budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ohenedarkohfrank@gmail.com"]
  }

  # Alert when actual monthly spending reaches 80% of the budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ohenedarkohfrank@gmail.com"]
  }

  # Alert when actual monthly spending exceeds the budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ohenedarkohfrank@gmail.com"]
  }
}




# IAM role that Redshift Serverless will assume to access S3.
resource "aws_iam_role" "redshift_s3_access" {
  name = "agrolens-redshift-s3-access"

  # Both service principals are included for Redshift Serverless compatibility.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "redshift.amazonaws.com",
          "redshift-serverless.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "AgroLens"
    Environment = "Development"
  }
}

# Restrict Redshift to listing and reading objects in our S3 data lake.
resource "aws_iam_role_policy" "redshift_s3_read" {
  name = "agrolens-s3-read-access"
  role = aws_iam_role.redshift_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.data_lake.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/*"
      }
    ]
  })
}
