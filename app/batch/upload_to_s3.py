# Uploads ./data/*.csv to s3://<raw_bucket>/batch/
import os, boto3, sys, glob

raw_bucket = sys.argv[1]
s3 = boto3.client('s3')
for fp in glob.glob('data/*.csv'):
    key = f"batch/{os.path.basename(fp)}"
    print('upload', fp, '→', key)
    s3.upload_file(fp, raw_bucket, key)
