import os, csv, random, math, time
from datetime import datetime, timedelta

ROWS_TOTAL = 25_000_000     # ~1GB at ~40B/row after gzip; adjust if needed
ROWS_PER_FILE = 500_000
OUT_DIR = 'data'
COLS = ['ts','device_id','temp_c','humidity','status']
random.seed(7)

os.makedirs(OUT_DIR, exist_ok=True)
start = datetime.utcnow() - timedelta(days=7)

def row(i, dev):
    ts = (start + timedelta(seconds=i)).isoformat()
    temp = 15 + 10*math.sin(i/6000) + random.random()*2
    hum  = 40 + 20*math.sin(i/9000+1) + random.random()*5
    status = 'OK' if random.random()>0.01 else 'WARN'
    return [ts, f"dev-{dev:04d}", round(temp,2), round(hum,2), status]

written = 0
fidx = 0
while written < ROWS_TOTAL:
    out = os.path.join(OUT_DIR, f"iot_{fidx:04d}.csv")
    with open(out, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(COLS)
        for j in range(ROWS_PER_FILE):
            w.writerow(row(written+j, dev=(written+j)%1000))
    fidx += 1
    written += ROWS_PER_FILE
    print(f"wrote {out}")
