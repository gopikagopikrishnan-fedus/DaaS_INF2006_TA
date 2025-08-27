# Sends JSON events to Firehose delivery stream
import time, json, random, boto3, sys

stream_name = sys.argv[1]  # e.g., inf2006-minimal-fh-to-s3
fh = boto3.client('firehose')

def rec(i):
    return {"ts": int(time.time()*1000), "device_id": f"dev-{i%1000:04d}", "temp_c": 20+random.random()*10, "humidity": 30+random.random()*30}

batch = []
for i in range(10_000):
    batch.append({"Data": (json.dumps(rec(i))+"\n").encode()})
    if len(batch)==500:
        fh.put_record_batch(DeliveryStreamName=stream_name, Records=batch)
        batch = []
        time.sleep(0.5)
if batch:
    fh.put_record_batch(DeliveryStreamName=stream_name, Records=batch)
