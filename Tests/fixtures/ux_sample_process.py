"""Read-only per-process CPU and resident-memory sampling (KiB) during native tests."""
import argparse,json,pathlib,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--pid',type=int,required=True);p.add_argument('--out',required=True);p.add_argument('--seconds',type=int,default=45);a=p.parse_args()
rows=[]
for _ in range(a.seconds):
 s=subprocess.run(['ps','-p',str(a.pid),'-o','%cpu=,rss='],capture_output=True,text=True).stdout.strip().split()
 if len(s)!=2:break
 rows.append(dict(time=time.time(),cpu=float(s[0]),rss_kib=int(s[1])));time.sleep(1)
pathlib.Path(a.out).write_text(json.dumps(rows,indent=2))
