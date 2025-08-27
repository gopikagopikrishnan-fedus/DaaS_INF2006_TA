# Benchmarks CSV vs Parquet with Athena (simple wall-clock)
import time, boto3, sys

athena = boto3.client('athena')
s3 = boto3.client('s3')
DATABASE = sys.argv[1]          # e.g., inf2006_minimal_db
OUTPUT_S3 = sys.argv[2]         # e.g., s3://<curated-bucket>/athena-results/

Q_CSV_CNT = "SELECT count(*) FROM iot_raw"
Q_PAR_CNT = "SELECT count(*) FROM iot_parquet"

def run(sql):
    q = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={'Database': DATABASE},
        ResultConfiguration={'OutputLocation': OUTPUT_S3}
    )['QueryExecutionId']
    while True:
        s = athena.get_query_execution(QueryExecutionId=q)['QueryExecution']['Status']['State']
        if s in ('SUCCEEDED','FAILED','CANCELLED'): break
        time.sleep(1)
    return s

for name, sql in [("csv_count", Q_CSV_CNT), ("parquet_count", Q_PAR_CNT)]:
    t0 = time.time(); st = run(sql); dt = time.time()-t0
    print({'query': name, 'status': st, 'seconds': round(dt,2)})
