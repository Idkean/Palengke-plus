"""
Dump the raw text from one of the 11 missing PDFs to see its layout.
"""
import re
import urllib.request
from io import BytesIO
from pypdf import PdfReader

# September 9, 2026 - one of the consistently-missing ones
TARGET_LABEL = "September 9, 2026"
DA_PAGE = "https://calabarzon.da.gov.ph/da-calabarzon-bantay-presyo/"

req = urllib.request.Request(DA_PAGE, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=15) as r:
    html = r.read().decode("utf-8")

reports = re.findall(
    r'<a href="(https://drive\.google\.com/file/d/[^" ]+/view\?usp=sharing)"><center>([^<]+)</a>',
    html,
    flags=re.IGNORECASE,
)

target_url = None
for url, label in reports:
    if label.strip() == TARGET_LABEL:
        target_url = url
        break

if not target_url:
    print(f"Could not find {TARGET_LABEL} on DA page")
else:
    file_id = re.search(r"/d/([^/]+)", target_url).group(1)
    download_url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
    print(f"Downloading {TARGET_LABEL}...")
    req2 = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req2, timeout=30) as r:
        data = r.read()
    reader = PdfReader(BytesIO(data))
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    print(f"\n=== PDF TEXT ({len(text)} chars) ===\n")
    print(text[:4000])

