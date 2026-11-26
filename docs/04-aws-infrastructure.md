# Phase 4: AWS Infrastructure and Cloud Environment

## 1. Phase Overview

### Objective

The objective of Phase 4 was to provision the AWS infrastructure required to support AgroLens's cloud-based data platform.

The infrastructure needed to provide:

- Scalable object storage for the raw data lake.
- A cloud data warehouse for analytical workloads.
- Secure communication between the data warehouse and Amazon S3.
- Controlled access to the data warehouse from the development machine.
- Infrastructure that could be reproduced and managed through code.
- Cost controls to reduce the risk of unexpected AWS expenditure.

The infrastructure was provisioned using **Terraform**, with AWS as the cloud provider.

### Architecture decisions

The selected infrastructure consists of:

| Component | AWS service | Purpose |
|---|---|---|
| Data lake | Amazon S3 | Store raw source data and future ingestion outputs |
| Data warehouse | Amazon Redshift Serverless | Store and query analytical datasets |
| Access management | AWS IAM | Allow Redshift to access S3 |
| Network security | Amazon VPC Security Groups | Restrict access to Redshift |
| Credential management | AWS Secrets Manager | Manage the Redshift administrator password |
| Cost monitoring | AWS Budgets | Monitor monthly AWS expenditure |
| Compute protection | Redshift Usage Limits | Restrict monthly Redshift compute consumption |
| Infrastructure as Code | Terraform | Provision and manage AWS resources |

---

## 2. AWS Environment Configuration

### AWS account and region

The project uses the following AWS configuration:

| Setting | Value |
|---|---|
| AWS account | `254212223627` |
| AWS region | `eu-west-1` (Europe/Ireland) |
| AWS CLI profile | `agrolens-terraform` |
| IAM Identity Center permission set | `AgroLensTerraform` |
| IAM Identity Center user | `agrolens-developer` |
| Terraform AWS provider | `hashicorp/aws` |
| Provider version | `6.73.0` |

The `agrolens-terraform` profile authenticates through AWS IAM Identity Center rather than relying on long-lived access keys.

The AWS region was configured in Terraform so that resources are provisioned consistently in the same region.

### Terraform provider configuration

File: `terraform/provider.tf`

The provider configuration specifies the AWS provider, its version constraint, the deployment region, and the AWS CLI profile.

The version constraint `~> 6.0` allows compatible AWS provider 6.x releases while preventing an unintended major-version upgrade.

---

## 3. Infrastructure as Code Structure

Terraform was used to provision the AWS infrastructure declaratively.

The Terraform configuration describes the desired infrastructure. Terraform compares that configuration with its recorded state and the existing AWS resources to determine what needs to be created, modified, or destroyed.

### Project structure

The relevant directory structure is:

```text
agrolens/
│
├── terraform/
│   ├── .terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfstate
│   └── modules/
│
└── docs/
```

The configuration files have separate responsibilities:

| File | Responsibility |
|---|---|
| `provider.tf` | AWS provider configuration and version constraints |
| `main.tf` | AWS resource definitions |
| `variables.tf` | Reusable configuration values |
| `outputs.tf` | Values Terraform can expose after deployment |
| `.terraform.lock.hcl` | Records the selected provider versions |
| `terraform.tfstate` | Records Terraform's understanding of managed resources |
| `modules/` | Location for reusable Terraform modules |

### Terraform state and security

Terraform state can contain sensitive infrastructure information and must not be committed to a public Git repository.

The following should be excluded through `.gitignore`:

```gitignore
# Terraform working directory and downloaded providers
.terraform/

# Terraform state files and backups
*.tfstate
*.tfstate.*

# Local variable files that may contain sensitive values
*.tfvars
*.tfvars.json
```

The provider lock file `.terraform.lock.hcl` should be committed so that future environments can use the same selected provider versions.

Terraform state is currently maintained locally. This is sufficient for the current individual development workflow, but a remote backend with appropriate access controls and state locking should be considered if the project becomes collaborative or moves into a shared deployment environment.

---

## ## 4. Amazon S3 Data Lake: Creation and Configuration

### 4.1 Purpose of the S3 Data Lake

Amazon Simple Storage Service (Amazon S3) was selected as the object storage layer for AgroLens.

The data lake will hold source datasets collected from different agricultural data providers, including:

- Ghana Ministry of Food and Agriculture / SRID market price data.
- World Food Programme (WFP) historical market price data.
- FAOSTAT agricultural statistics.
- Open-Meteo weather data.

S3 provides durable, scalable object storage and separates raw data storage from analytical processing.

This separation is important because source data should be preserved independently of the transformations performed in the data warehouse.

The intended data flow is:

1. Python ingestion scripts retrieve data from external sources.
2. Retrieved data is validated and prepared for storage.
3. Original or raw source files are uploaded to S3.
4. Redshift accesses the stored data when required.
5. dbt transforms the data into analytical models.

The S3 bucket was provisioned during Phase 4 so that the cloud storage foundation would be ready before implementing the ingestion pipeline in Phase 5.

### 4.2 Bucket Creation

The following S3 bucket was created:

| Configuration | Value |
|---|---|
| Bucket name | `agrolens-data-lake-254212223627` |
| AWS region | `eu-west-1` |
| Terraform resource | `aws_s3_bucket.data_lake` |
| Versioning | Enabled |
| Default encryption | SSE-S3 (AES256) |
| Public access | Blocked |

The AWS account ID was included in the bucket name to make the name globally unique.

S3 bucket names must be globally unique within the AWS partition. Including the account ID reduces the likelihood of naming conflicts with buckets owned by other AWS accounts.

The bucket was created using Terraform rather than manually through the AWS Management Console.

This makes the bucket configuration reproducible and allows future infrastructure changes to be managed through code.

### 4.3 Terraform Implementation

The bucket and its security configurations are defined in `terraform/main.tf`.

The implementation uses four Terraform resources:

1. `aws_s3_bucket.data_lake`
2. `aws_s3_bucket_public_access_block.data_lake`
3. `aws_s3_bucket_server_side_encryption_configuration.data_lake`
4. `aws_s3_bucket_versioning.data_lake`

Each resource manages a separate aspect of the bucket configuration.

#### 4.3.1 Create the S3 Bucket

```hcl
# Create the central S3 bucket for AgroLens data storage.
resource "aws_s3_bucket" "data_lake" {
  bucket = "agrolens-data-lake-254212223627"

  # Tags make the resource easier to identify and manage in AWS.
  tags = {
    Name        = "agrolens-data-lake"
    Project     = "AgroLens"
    Environment = "Development"
  }
}
```

**Explanation**

- `resource` declares an AWS resource that Terraform should manage.
- `aws_s3_bucket` identifies the resource type.
- `data_lake` is Terraform's local reference name for the bucket.
- `bucket` specifies the globally unique S3 bucket name.
- `tags` attach metadata to the resource.

The `Project` and `Environment` tags help identify which application owns the resource and whether it belongs to a development or production environment.

#### 4.3.2 Block Public Access

```hcl
# Prevent public access to the AgroLens data lake.
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  # Prevent public access through bucket-level access control lists.
  block_public_acls = true

  # Prevent new public bucket policies and restrict public policies.
  block_public_policy = true

  # Ignore public ACLs that may already exist.
  ignore_public_acls = true

  # Restrict access granted through public bucket policies.
  restrict_public_buckets = true
}
```

**Explanation**

S3 supports different mechanisms for granting access to buckets and objects. These include access control lists (ACLs) and bucket policies.

Blocking public access provides an additional security layer that helps prevent accidental exposure of sensitive data.

The four settings have distinct responsibilities:

| Setting | Purpose |
|---|---|
| `block_public_acls` | Prevents new public ACLs from being applied |
| `block_public_policy` | Blocks public bucket policies |
| `ignore_public_acls` | Ignores public ACL permissions |
| `restrict_public_buckets` | Restricts access through public bucket policies |

All four settings are enabled.

This is particularly important because AgroLens may eventually store datasets containing commercially sensitive market information or other data that should not be publicly exposed.

The bucket is intended for controlled access by authorized AWS services and application components.

#### 4.3.3 Configure Server-Side Encryption

```hcl
# Enable default server-side encryption for objects stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      # Use Amazon S3-managed encryption keys (SSE-S3).
      sse_algorithm = "AES256"
    }
  }
}
```

**Explanation**

Server-side encryption protects objects stored in S3 by encrypting them at rest.

The configuration uses SSE-S3, which means Amazon S3 manages the encryption keys and performs the encryption and decryption operations.

`AES256` identifies the encryption algorithm used by SSE-S3.

This approach was selected because it provides encryption at rest without requiring the project to create and manage a separate AWS Key Management Service (KMS) key.

An alternative is SSE-KMS, which provides additional key-management controls and auditing capabilities. However, it introduces additional configuration and potentially additional costs.

For the current development environment, SSE-S3 is sufficient.

#### 4.3.4 Enable Bucket Versioning

```hcl
# Enable versioning to preserve previous versions of stored objects.
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Explanation**

S3 versioning maintains multiple versions of an object under the same object key.

For example, if an ingestion process uploads a corrected version of a dataset using the same object key, S3 can preserve the earlier version.

Versioning provides protection against:

- Accidental overwriting of files.
- Unintended deletion of objects.
- Incorrect ingestion outputs replacing previous versions.
- Some forms of accidental data modification.

Versioning does not replace a complete backup strategy, but it provides an important recovery mechanism.

It can also increase storage costs because previous versions continue to occupy storage.

Lifecycle policies may be introduced later to manage older object versions as the data lake grows.

### 4.4 Understanding Terraform Resource References

The S3 configuration uses references such as:

```hcl
bucket = aws_s3_bucket.data_lake.id
```

This is an example of Terraform's implicit dependency mechanism.

Rather than hardcoding the bucket name in every resource, the configuration references the ID of the bucket resource.

Terraform understands that the public access block, encryption configuration, and versioning configuration depend on the bucket being created first.

This helps Terraform determine the correct resource creation order.

It also reduces duplication and makes the configuration easier to maintain.

### 4.5 Deployment Process

The S3 bucket and its configurations were deployed using Terraform.

The deployment process followed these steps:

**Step 1: Initialize Terraform**

```powershell
# Initialize the working directory and download the AWS provider.
terraform init
```

**Step 2: Validate the configuration**

```powershell
# Check the Terraform configuration for syntax and structural errors.
terraform validate
```

**Step 3: Generate an execution plan**

```powershell
# Preview the AWS resources Terraform intends to create or modify.
terraform plan -out="agrolens.tfplan"
```

**Step 4: Inspect the execution plan**

```powershell
# Display the planned resource changes before deployment.
terraform show "agrolens.tfplan"
```

**Step 5: Apply the reviewed plan**

```powershell
# Create the S3 bucket and apply its associated configurations.
terraform apply "agrolens.tfplan"
```

The S3 resources were successfully created and subsequently managed through Terraform.

### 4.6 Verify the S3 Configuration

The bucket configuration can be verified through both the AWS Management Console and AWS CLI.

The following commands provide independent checks of the deployed configuration.

**Verify bucket existence and region**

```powershell
# Retrieve the bucket's region.
aws s3api get-bucket-location `
    --bucket agrolens-data-lake-254212223627 `
    --profile agrolens-terraform `
    --no-cli-pager
```

The expected region is `eu-west-1`.

**Verify public access blocking**

```powershell
# Retrieve the four public access block settings.
aws s3api get-public-access-block `
    --bucket agrolens-data-lake-254212223627 `
    --profile agrolens-terraform `
    --no-cli-pager
```

All four settings should return `true`.

**Verify default encryption**

```powershell
# Check the bucket's default server-side encryption configuration.
aws s3api get-bucket-encryption `
    --bucket agrolens-data-lake-254212223627 `
    --profile agrolens-terraform `
    --no-cli-pager
```

The expected encryption algorithm is `AES256`.

**Verify versioning**

```powershell
# Check whether S3 bucket versioning is enabled.
aws s3api get-bucket-versioning `
    --bucket agrolens-data-lake-254212223627 `
    --profile agrolens-terraform `
    --no-cli-pager
```

The expected status is `Enabled`.

These commands verify the actual AWS configuration rather than relying only on the Terraform configuration files.

### 4.7 S3 Data Lake Organization: Planned Structure

The bucket has been provisioned, but the final ingestion folder structure will be implemented during Phase 5.

The intended organization is:

```text
agrolens-data-lake/
│
├── raw/
│   ├── srid/
│   ├── wfp/
│   ├── faostat/
│   └── open_meteo/
│
├── processed/
│   ├── srid/
│   ├── wfp/
│   ├── faostat/
│   └── open_meteo/
│
└── archive/
```

This is a proposed logical organization, not a claim that these folders have already been created.

S3 uses object keys rather than traditional filesystem directories. The folder-like structure is represented by prefixes in object keys.

For example:

```text
raw/srid/market_prices_2025.csv
```

The `raw/` prefix will contain source data as collected, while `processed/` will contain data prepared for downstream loading or transformation.

The `archive/` prefix can be used for older or superseded datasets if required by the ingestion and retention strategy.

The detailed naming convention, partitioning strategy, and object lifecycle policies will be finalized during the ingestion phase.

### 4.8 Why These S3 Configurations Matter

The four S3 resources address different infrastructure requirements:

| Configuration | Problem addressed |
|---|---|
| Bucket creation | Provides centralized object storage |
| Public access block | Reduces accidental public exposure |
| Server-side encryption | Protects stored objects at rest |
| Versioning | Supports recovery from accidental overwrites and deletions |

Together, these configurations establish a secure baseline for the AgroLens data lake.

### 4.9 Limitations and Future Improvements

The following are not yet implemented:

- Lifecycle rules for managing older object versions.
- Data retention policies.
- Cross-region replication.
- Automated ingestion into the bucket.
- Object-level metadata standards.
- Finalized partitioning and naming conventions.
- Dedicated application IAM permissions for Python ingestion.

These decisions will be addressed when the ingestion architecture is implemented and actual storage requirements become clearer.

**Phase 4 outcome:** The AgroLens S3 data lake was successfully provisioned through Terraform with public access blocked, AES256 default encryption enabled, and bucket versioning enabled. It is ready to serve as the storage foundation for Phase 5 ingestion.
---

## 5. Amazon Redshift Serverless

### Why Redshift Serverless?

Amazon Redshift was selected as the analytical warehouse for AgroLens.

The project could technically use PostgreSQL for its current data volume. The existing datasets are relatively small compared with the volumes typically associated with enterprise data warehouses.

However, Redshift Serverless was selected to provide practical experience with:

- Cloud data warehouse architecture.
- AWS-native data loading.
- IAM-based access to S3.
- Serverless compute management.
- Warehouse connectivity from Python.
- Cloud cost monitoring and usage controls.

This is a learning and portfolio decision rather than a claim that Redshift is the cheapest or only suitable solution for the current dataset size.

Redshift Serverless removes the need to provision and manage a traditional fixed cluster. Compute capacity is measured in Redshift Processing Units (RPUs).

### Namespace configuration

The namespace was created with the following configuration:

| Setting | Value |
|---|---|
| Namespace name | `agrolens` |
| Database name | `agrolens` |
| Administrator username | `agrolens_admin` |
| Password management | AWS Secrets Manager |
| Terraform resource | `aws_redshiftserverless_namespace.agrolens` |

The administrator password is managed by AWS because the namespace uses:

`manage_admin_password = true`

The password should not be hardcoded into Terraform files, Python scripts, or Git.

### Workgroup configuration

The Redshift Serverless workgroup was configured as follows:

| Setting | Value |
|---|---|
| Workgroup name | `agrolens-workgroup` |
| Namespace | `agrolens` |
| Base capacity | 4 RPUs |
| Maximum capacity | 4 RPUs |
| Port | 5439 |
| Public accessibility | Enabled |
| Region | `eu-west-1` |
| Status after deployment | `AVAILABLE` |

The workgroup endpoint is:

```text
agrolens-workgroup.254212223627.eu-west-1.redshift-serverless.amazonaws.com
```

The endpoint is used by the Python application to connect to the warehouse.

### Why 4 RPUs?

Four RPUs were selected as the initial compute configuration.

The objective was to use a relatively small compute allocation suitable for development and initial analytical workloads.

The maximum capacity was also set to 4 RPUs to prevent the workgroup from scaling above the selected capacity.

This is a deliberate development configuration. Performance should be evaluated as the data volume and query complexity increase.

### Public accessibility

The workgroup was configured with public accessibility enabled.

This allows the development machine to connect directly to Redshift without first deploying a separate application server or VPN connection.

Public accessibility does not mean that the warehouse is open to every internet user. The security group restricts inbound connections to the approved public IP address.

This is a development convenience with a security trade-off. A production deployment should evaluate private networking, controlled application access, and other appropriate network restrictions.

### Terraform resources

- `aws_redshiftserverless_namespace.agrolens`
- `aws_redshiftserverless_workgroup.agrolens`

---

## 6. IAM: Redshift Access to S3

### Objective

Redshift needs permission to access objects in the AgroLens S3 data lake.

Instead of embedding AWS access keys in scripts or database commands, a dedicated IAM role was created and associated with the Redshift namespace.

This follows the AWS role-based access model.

### IAM role

Role name:

`agrolens-redshift-s3-access`

Terraform resource:

`aws_iam_role.redshift_s3_access`

The role's trust policy allows the relevant Redshift services to assume the role.

### IAM permissions

A dedicated inline policy was attached to the role.

Policy name:

`agrolens-s3-read-access`

Terraform resource:

`aws_iam_role_policy.redshift_s3_read`

The policy grants the following permissions:

| Permission | Purpose |
|---|---|
| `s3:ListBucket` | List objects in the AgroLens bucket |
| `s3:GetBucketLocation` | Retrieve the bucket's region |
| `s3:GetObject` | Read objects stored in the bucket |

The bucket-level permissions apply to the bucket ARN, while the object-read permission applies to objects within the bucket.

The policy does not grant write or delete permissions.

This follows the principle of least privilege: Redshift receives only the S3 permissions required for the intended read operations.

### Role association

The role ARN was associated with the Redshift namespace and configured as its default IAM role.

This will allow Redshift to use the role when executing supported operations that access S3.

The role does not give the Python application direct access to S3. The application's own AWS permissions will be configured separately if required.

---

## 7. Network Security and Redshift Connectivity

### VPC configuration

The Redshift workgroup uses the existing default VPC.

| Setting | Value |
|---|---|
| VPC ID | `vpc-0e3f69478e29d8dc7` |
| VPC CIDR | `172.31.0.0/16` |
| Region | `eu-west-1` |

The workgroup was configured to use three subnets across three Availability Zones:

| Subnet | Availability Zone | CIDR |
|---|---|---|
| `subnet-097f369bbba8e9170` | eu-west-1b | `172.31.32.0/20` |
| `subnet-0116635fb32eb14ae` | eu-west-1a | `172.31.16.0/20` |
| `subnet-0f55c36177afd4cf4` | eu-west-1c | `172.31.0.0/20` |

### Security group

A dedicated security group was created:

| Setting | Value |
|---|---|
| Name | `agrolens-redshift-sg` |
| Security group ID | `sg-05acdc92a26f50007` |
| Protocol | TCP |
| Port | 5439 |
| Inbound source | Approved public IPv4 address with `/32` |
| Outbound | All traffic |

Terraform resource:

`aws_security_group.redshift`

The inbound rule permits connections only from the configured client IP address.

The `/32` CIDR suffix represents one IPv4 address, rather than a broad network range.

The security group must not be changed to allow `0.0.0.0/0` merely to resolve connectivity problems.

### Connectivity issue and resolution

During the initial Python connection test, the connection timed out.

The Redshift workgroup was available, but the development machine could not establish a TCP connection on port 5439.

The investigation identified that the public IP address had changed.

The original security group rule allowed:

```text
154.161.21.122/32
```

The current public IP address was:

```text
154.161.44.219
```

The Terraform variable `allowed_client_cidr` was updated to the new IP.

A new Terraform plan was generated and inspected before applying the change.

The plan showed:

```text
Plan: 0 to add, 1 to change, 0 to destroy.
```

Only the existing security group's ingress rule was updated in place.

After applying the plan, the Python connection succeeded.

**Lesson:** When a cloud database is publicly accessible but a connection times out, check the network path and allowed client IP before changing credentials or recreating the database.

A dynamic public IP can cause this issue again. If it does, update the Terraform variable, review a fresh plan, and apply only the intended security-group change.

---

## 8. Credential Management and Python Connectivity

### Credential management

The Redshift administrator password is managed by AWS Secrets Manager.

The password was retrieved through the AWS CLI using the IAM Identity Center profile.

The AWS CLI session initially expired, producing an SSO token error. The session was refreshed using:

```powershell
# Re-authenticate the AWS CLI profile through IAM Identity Center.
aws sso login --profile agrolens-terraform
```

The caller identity can be checked with:

```powershell
# Confirm the identity associated with the active AWS profile.
aws sts get-caller-identity --profile agrolens-terraform
```

The secret was then retrieved from Secrets Manager.

Credentials must not be committed to the repository or pasted into source code.

### Environment variables

The Python connection script reads its settings from the project's `.env` file.

Example configuration:

```env
REDSHIFT_HOST=agrolens-workgroup.254212223627.eu-west-1.redshift-serverless.amazonaws.com
REDSHIFT_PORT=5439
REDSHIFT_DATABASE=agrolens
REDSHIFT_USER=agrolens_admin
REDSHIFT_PASSWORD=your_retrieved_password
```

The actual password must remain private.

The `.env` file must be excluded through `.gitignore`.

### Python connection test

File:

`scripts/test_redshift_connection.py`

The connection test uses:

- `psycopg2` to connect to Redshift.
- `python-dotenv` to load environment variables.
- `sslmode="require"` to require SSL encryption.
- A connection timeout to avoid waiting indefinitely.

The script executes:

```sql
SELECT
    current_database(),
    current_user,
    GETDATE();
```

This verifies that the connection can execute a query and retrieve the database name, authenticated user, and server timestamp.

### Successful verification

The following output was obtained:

```text
Database: agrolens
User: agrolens_admin
Server time: 2026-11-26 22:52:24
Connection closed.
```

This confirms that:

1. The Redshift endpoint is reachable.
2. The supplied credentials are accepted.
3. The application can connect to the intended database.
4. SQL statements can be executed.
5. The connection is closed after use.

This is a connectivity test, not yet a test of loading data into Redshift.

---

## 9. AWS Cost Management

Cost management was included in the infrastructure design because Redshift Serverless and other AWS services can incur charges even when a project is only being developed.

Two separate controls were configured.

### 9.1 Redshift Serverless usage limit

Terraform resource:

`aws_redshiftserverless_usage_limit.agrolens`

Configuration:

| Setting | Value |
|---|---|
| Usage type | `serverless-compute` |
| Amount | 20 RPU-hours |
| Period | Monthly |
| Breach action | `deactivate` |

The workgroup is configured with a maximum capacity of 4 RPUs.

At 4 RPUs, 20 RPU-hours represent approximately five hours of compute at that capacity.

This is a compute usage limit, not a complete cap on Redshift expenditure.

Redshift managed storage and other separately billed components are not protected by this compute limit.

### 9.2 AWS Budget

Terraform resource:

`aws_budgets_budget.agrolens`

Configuration:

| Setting | Value |
|---|---|
| Budget name | `agrolens-monthly-budget` |
| Budget type | Cost |
| Period | Monthly |
| Budget amount | USD 15 |
| Notification type | Actual expenditure |
| Alert thresholds | 50%, 80%, 100% |
| Notification email | Configured project email |

The budget sends notifications when actual expenditure reaches the configured thresholds.

The budget is an alerting mechanism, not an automatic spending cap. Reaching the budget does not automatically stop every AWS service.

### 9.3 AWS credits

The AWS console showed a separate Redshift Serverless free-trial balance of USD 300.

This credit should be monitored through the AWS billing and credits pages.

The previously displayed USD 100 AWS Free Tier credit had expired on 19 November 2026 and should not be counted as available funding.

Credits may reduce eligible charges, but the project should still be managed as if normal charges could apply. The actual billing dashboard is the source of truth for credit usage and remaining balances.

### Cost-management lessons

- Serverless does not mean free.
- Compute and storage can be billed separately.
- Usage limits and budgets protect against different types of costs.
- Budget notifications are not hard spending limits.
- Redshift should be monitored and deactivated when it is not needed for development.
- S3 versioning can increase storage usage over time.
- Free-trial credits should not replace cost monitoring.

---

## 10. Terraform Deployment and Verification

The infrastructure was deployed in stages.

### Authentication

```powershell
# Authenticate the configured AWS CLI profile.
aws sso login --profile agrolens-terraform
```

### Terraform initialization

```powershell
# Initialize Terraform and download the required provider.
terraform init
```

### Formatting and validation

```powershell
# Format Terraform configuration files.
terraform fmt -recursive

# Validate the Terraform configuration.
terraform validate
```

### Plan

```powershell
# Generate a saved deployment plan.
terraform plan -out="agrolens.tfplan"

# Inspect the proposed changes.
terraform show "agrolens.tfplan"
```

### Apply

```powershell
# Apply the reviewed Terraform plan.
terraform apply "agrolens.tfplan"
```

The initial deployment completed with:

```text
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
```

The existing S3 infrastructure was already managed in Terraform before this deployment.

The subsequent IP correction completed as an in-place security-group update:

```text
Plan: 0 to add, 1 to change, 0 to destroy.
```

### Redshift workgroup verification

The AWS CLI was used to inspect the deployed workgroup:

```powershell
# Retrieve the workgroup's operational and connection details.
aws redshift-serverless get-workgroup `
    --workgroup-name agrolens-workgroup `
    --region eu-west-1 `
    --profile agrolens-terraform `
    --query "workgroup.{Status:status,Endpoint:endpoint.address,Port:endpoint.port,BaseCapacity:baseCapacity,MaxCapacity:maxCapacity,PubliclyAccessible:publiclyAccessible,SecurityGroups:securityGroupIds}" `
    --output table `
    --no-cli-pager
```

The returned details confirmed:

- Status: `AVAILABLE`
- Base capacity: 4
- Maximum capacity: 4
- Port: 5439
- Public accessibility: enabled
- Security group: `sg-05acdc92a26f50007`

The namespace was also inspected to confirm the database and administrator username.

### Python connectivity verification

```powershell
# Run the Python connection test.
python scripts/test_redshift_connection.py
```

The test successfully returned the database, user, and server timestamp.

---

## 11. Resources Provisioned

The following Terraform resources form the Phase 4 infrastructure.

| Resource | Terraform resource |
|---|---|
| S3 bucket | `aws_s3_bucket.data_lake` |
| S3 public access block | `aws_s3_bucket_public_access_block.data_lake` |
| S3 encryption | `aws_s3_bucket_server_side_encryption_configuration.data_lake` |
| S3 versioning | `aws_s3_bucket_versioning.data_lake` |
| Redshift IAM role | `aws_iam_role.redshift_s3_access` |
| Redshift IAM policy | `aws_iam_role_policy.redshift_s3_read` |
| Redshift namespace | `aws_redshiftserverless_namespace.agrolens` |
| Redshift workgroup | `aws_redshiftserverless_workgroup.agrolens` |
| Redshift security group | `aws_security_group.redshift` |
| Redshift usage limit | `aws_redshiftserverless_usage_limit.agrolens` |
| AWS monthly budget | `aws_budgets_budget.agrolens` |

These are the 11 Terraform-managed resource instances associated with the completed infrastructure configuration.

---

## 12. Security and Operational Considerations

The following practices should continue throughout the project:

1. Never commit `.env`, Terraform state files, or AWS credentials.
2. Use IAM Identity Center for interactive AWS authentication.
3. Keep Redshift inbound access restricted to the approved client IP.
4. Avoid hardcoding administrator passwords in Python or Terraform.
5. Use IAM roles for AWS service-to-service access.
6. Review Terraform plans before applying infrastructure changes.
7. Monitor AWS Budgets and Redshift usage limits.
8. Deactivate or otherwise manage Redshift compute when it is not needed.
9. Monitor S3 storage growth and object versioning.
10. Keep the Terraform provider lock file committed.

---

## 13. Limitations and Outstanding Considerations

The following items are not claimed as completed by this phase:

- No source datasets have been ingested into S3 yet.
- No Redshift tables have been created for the AgroLens analytical datasets.
- No S3-to-Redshift data loading has been implemented.
- No dbt models have been deployed.
- No Airflow orchestration has been implemented.
- No CI/CD deployment workflow has been implemented.
- The Terraform state is still local rather than stored in a remote backend.
- Redshift uses public accessibility with a restricted IP allowlist, rather than a private-only network design.
- The budget is a notification mechanism, not a hard spending limit.

These are deliberate boundaries between infrastructure provisioning and subsequent data engineering phases.

---

## 14. Phase Completion Criteria

| Requirement | Status |
|---|---|
| AWS authentication configured | Complete |
| Terraform AWS provider configured | Complete |
| S3 data lake provisioned | Complete |
| S3 public access blocked | Complete |
| S3 encryption enabled | Complete |
| S3 versioning enabled | Complete |
| Redshift namespace provisioned | Complete |
| Redshift Serverless workgroup provisioned | Complete |
| Redshift IAM role created | Complete |
| S3 read permissions associated with Redshift | Complete |
| Redshift security group configured | Complete |
| Redshift usage limit configured | Complete |
| Monthly AWS budget configured | Complete |
| Managed administrator password retrieved | Complete |
| Python-to-Redshift connection tested | Complete |

**Phase 4 is technically complete.** The remaining activity before merging is the final AWS Console verification and review of the Git changes.

---

## 15. Key Lessons from Phase 4

This phase provided practical experience with several important cloud data engineering concepts.

**Infrastructure as Code:** Terraform makes infrastructure reproducible and allows proposed changes to be reviewed before deployment.

**Separation of responsibilities:** S3 provides object storage, while Redshift provides analytical compute and querying.

**IAM roles:** AWS services can be granted access to other AWS services without embedding long-lived credentials.

**Network security:** A publicly accessible endpoint still needs carefully controlled network access. A changing client IP can interrupt connectivity even when the database itself is healthy.

**Secrets management:** Database credentials should be managed separately from application source code.

**Serverless cost awareness:** Serverless infrastructure still incurs charges. Compute usage limits, budgets, and operational discipline are important.

**Troubleshooting:** The initial database timeout was caused by a mismatch between the current public IP and the security-group allowlist, not by invalid database credentials.

These lessons are directly reusable when designing cloud data platforms for other projects.

---

## 16. Next Phase

The next phase is **Phase 5: Data Ingestion**.

The planned work will focus on:

1. Defining the S3 data lake folder and object-key structure.
2. Designing the Python ingestion architecture.
3. Implementing source-specific ingestion for SRID, WFP, FAOSTAT, and weather data.
4. Adding logging and error handling.
5. Validating data before uploading it.
6. Uploading raw data to the appropriate S3 locations.
7. Verifying uploaded objects and metadata.
8. Documenting ingestion behaviour, failure handling, and rerun considerations.

The objective is to build a reliable, explainable ingestion pipeline rather than simply upload files to S3.