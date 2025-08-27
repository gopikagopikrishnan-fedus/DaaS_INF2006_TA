# Minimal Great Expectations validation on a CSV sample (local or S3)
import os, io, boto3, pandas as pd
from great_expectations.dataset import PandasDataset

SRC = os.environ.get('SRC', 's3')
BUCKET = os.environ.get('RAW_BUCKET')
KEY = os.environ.get('RAW_KEY', 'batch/iot_0000.csv')

if SRC == 's3':
    s3 = boto3.client('s3')
    obj = s3.get_object(Bucket=BUCKET, Key=KEY)
    df = pd.read_csv(io.BytesIO(obj['Body'].read()))
else:
    df = pd.read_csv('data/iot_0000.csv')

class IotDataset(PandasDataset):
    pass

d = IotDataset(df)
# Expectations
results = []
results.append(d.expect_column_values_to_not_be_null('ts'))
results.append(d.expect_column_values_to_match_regex('device_id', r'^dev-\d{4}$'))
results.append(d.expect_column_values_to_be_between('temp_c', -40, 85))
results.append(d.expect_column_values_to_be_between('humidity', 0, 100))

ok = all(r['success'] for r in results)
print({'success': ok, 'results': [{k:r[k] for k in ('expectation_config','success')} for r in results]})
