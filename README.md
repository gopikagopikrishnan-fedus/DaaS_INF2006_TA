# INF2006 Minimal DaaS — Quick Start

## Prereqs
- AWS account, IAM user with admin for bootstrap
- Terraform >=1.5, AWS CLI, Python 3.11, boto3, great_expectations, pyarrow, pandas

## 1) Deploy Infra
cd infra/terraform
terraform init
terraform apply -auto-approve
# Note outputs: raw_bucket, curated_bucket, http_api_url

## 2) Generate & Upload ~1GB Batch Data
cd app/batch
python generate_dataset.py
python upload_to_s3.py <raw_bucket>

## 3) Create Athena Tables & Curate to Parquet
# Update analytics/athena/queries.sql with bucket names; run in Athena console or via AWS CLI.
# After CTAS, curated data at s3://<curated-bucket>/curated/iot_parquet/

## 4) Streaming Ingest
cd app/stream
python producer.py inf2006-minimal-fh-to-s3  # stream name from Terraform

## 5) API Access Pattern
curl "<http_api_url>/data?prefix=curated/iot_parquet/&limit=10"

## 6) Data Quality Check (GE)
cd quality
export RAW_BUCKET=<raw_bucket>
python validate_ge.py  # prints success and brief results

## 7) Storage Benchmark (Athena)
cd benchmarks
python benchmark_storage.py inf2006_minimal_db s3://<curated-bucket>/athena-results/

## 8) Minimal Monitoring & Security
- CloudWatch logs enabled for Lambda/Firehose/Glue
- Buckets private; access via presigned URLs (API)
- IAM roles least-privilege in Terraform baseline

## 9) Mid-term Deliverables Pointers
- Video: show 3 access patterns + GE report + benchmark printout
- Report: include arch diagram, data flow, GE summary, CSV vs Parquet timings
- Repo: this tree + IaC
