import re
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
        valid.append((d, label.strip()))
    except Exception:
        pass

valid.sort(reverse=True)
print(f"Total reports found on DA page: {len(valid)}")
print()
for d, label in valid:
    print(label)

