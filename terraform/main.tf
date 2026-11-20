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