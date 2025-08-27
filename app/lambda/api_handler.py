import os, json, boto3
from urllib.parse import unquote

s3 = boto3.client('s3')
BUCKET = os.environ['CURATED_BUCKET']

def list_objects(prefix: str, limit: int = 20):
    resp = s3.list_objects_v2(Bucket=BUCKET, Prefix=prefix, MaxKeys=limit)
    keys = [x['Key'] for x in resp.get('Contents', [])]
    urls = [s3.generate_presigned_url('get_object', Params={'Bucket': BUCKET, 'Key': k}, ExpiresIn=3600) for k in keys]
    return [{"key": k, "url": u} for k, u in zip(keys, urls)]

def handler(event, context):
    qp = event.get('queryStringParameters') or {}
    prefix = unquote(qp.get('prefix', 'curated/'))
    try:
        limit = int(qp.get('limit', '20'))
    except:
        limit = 20
    items = list_objects(prefix, limit)
    return {"statusCode": 200, "headers": {"content-type": "application/json"}, "body": json.dumps({"count": len(items), "items": items})}
