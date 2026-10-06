import re
import sqlite3
import urllib.request
from datetime import datetime

DA_PAGE = "https://calabarzon.da.gov.ph/da-calabarzon-bantay-presyo/"
req = urllib.request.Request(DA_PAGE, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=15) as r:
    html = r.read().decode("utf-8")

reports = re.findall(
    r'<a href="(https://drive\.google\.com/file/d/[^" ]+/view\?usp=sharing)"><center>([^<]+)</a>',
    html,
    flags=re.IGNORECASE,
)
valid = []
for url, label in reports:
    try:
        d = datetime.strptime(label.strip(), "%B %d, %Y")
        valid.append((d, label.strip(), d.date().isoformat()))
    except Exception:
        pass
valid.sort(reverse=True)
top40 = valid[:40]

c = sqlite3.connect(r"C:\Users\Admin\Desktop\Palengke+\backend\calamba_prices.db")
existing = {r[0] for r in c.execute("SELECT DISTINCT date FROM prices")}
c.close()

SKIP = {"September 18, 2026", "September 16, 2026"}

print("=== 40 reports in scope ===")
for d, label, iso in top40:
    if label in SKIP:
        status = "SKIP(bad)"
    elif iso in existing:
        status = "IN DB"
    else:
        status = "*** MISSING ***"
    print(f"  [{status:14}] {label}  ({iso})")

missing = [(label, iso) for d, label, iso in top40 if iso not in existing and label not in SKIP]
print(f"\nMissing from DB: {len(missing)}")
for label, iso in missing:
    print(f"  -> {label}  ({iso})")

