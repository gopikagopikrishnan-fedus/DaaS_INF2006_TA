-- Create external table over RAW CSV (Glue crawler can also create this)
-- Adjust S3 URIs and column types as needed
CREATE DATABASE IF NOT EXISTS inf2006_minimal_db;

CREATE EXTERNAL TABLE IF NOT EXISTS iot_raw (
  ts string,
  device_id string,
  temp_c double,
  humidity double,
  status string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar'=',','quoteChar'='"','escapeChar'='\\')
LOCATION 's3://<raw-bucket>/batch/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Convert to Parquet (curated)
CREATE TABLE iot_parquet
WITH (
  format='PARQUET',
  external_location = 's3://<curated-bucket>/curated/iot_parquet/',
  partitioned_by = ARRAY['status']
) AS
SELECT from_iso8601_timestamp(ts) AS ts, device_id, temp_c, humidity, status
FROM iot_raw;

-- Example analytics
SELECT device_id, avg(temp_c) AS avg_temp, approx_percentile(humidity,0.95) AS p95_hum
FROM iot_parquet
WHERE date(ts) >= current_date - interval '3' day
GROUP BY device_id
ORDER BY avg_temp DESC
LIMIT 50;
