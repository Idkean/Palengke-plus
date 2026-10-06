import re
import sqlite3
import urllib.request
from io import BytesIO
from datetime import datetime

from pypdf import PdfReader

from database import DB_PATH, init_db, insert_price

DA_PAGE = "https://calabarzon.da.gov.ph/da-calabarzon-bantay-presyo/"
SOURCE = "Department of Agriculture IV-A CALABARZON Bantay Presyo"
COVERAGE = "CALABARZON Region IV-A public markets"
REPORT_HISTORY_LIMIT = 40  # fetch 40 to absorb skipped/unreadable PDFs and land on 30+ real dates
SKIP_REPORT_LABELS = {"September 18, 2026", "September 16, 2026"}

COMMODITIES = {
    "well-milled rice": ("Grains", "Well Milled 1-19% bran streak"),
    "regular milled rice": ("Grains", "Regular Milled 20-40% bran streak"),
    "premium 5% broken rice": ("Grains", "Premium 5% broken"),
    "yellow corn": ("Grains", "Corn (Yellow) Cob"),
    "ampalaya": ("Vegetables", "Ampalaya"),
    "kamatis": ("Vegetables", "Tomato"),
    "talong": ("Vegetables", "Eggplant"),
    "repolyo": ("Vegetables", "Cabbage (Rare Ball)"),
    "sitaw": ("Vegetables", "Pole Sitao"),
    "kalabasa": ("Vegetables", "Squash"),
    "carrots": ("Vegetables", "Carrots, Local"),
    "red onion": ("Spices", "Red Onion, Local"),
    "white onion": ("Spices", "White Onion, Local"),
    "bawang": ("Spices", "Garlic, Native/Local"),
    "luya": ("Spices", "Ginger, Local"),
    "pork liempo": ("Meat", "Pork Belly (Liempo), Local"),
    "pork kasim": ("Meat", "Pork Picnic (Kasim), Local"),
    "beef rump": ("Meat", "Beef Rump, Local"),
    "chicken (whole)": ("Poultry", "Whole Chicken, Local"),
    "eggs (medium)": ("Poultry", "Chicken Egg (White, Medium)"),
    "bangus": ("Fish", "Bangus, Medium"),
    "tilapia": ("Fish", "Tilapia Medium"),
    "galunggong": ("Fish", "Galunggong, Local"),
}


def extract_report_links(html):
    reports = re.findall(
        r'<a href="(https://drive\.google\.com/file/d/[^" ]+/view\?usp=sharing)"><center>([^<]+)</a>',
        html,
        flags=re.IGNORECASE,
    )
    valid_reports = []
    for url, label in reports:
        try:
            date_value = datetime.strptime(label.strip(), "%B %d, %Y")
        except ValueError:
            continue
        valid_reports.append((url, label.strip(), date_value))
    valid_reports.sort(key=lambda report: report[2], reverse=True)
    return [(url, label) for url, label, _ in valid_reports[:REPORT_HISTORY_LIMIT]]


def weekly_links():
    html = download(DA_PAGE).decode("utf-8")
    return extract_report_links(html)


def download(url):
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (PalengkePlus official-data-sync)"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


def observation_date(text):
    daily = re.search(r"Daily Price Index - ([A-Za-z]+ \d{1,2}, \d{4})", text)
    if daily:
        return datetime.strptime(daily.group(1), "%B %d, %Y").date().isoformat()
    match = re.search(
        r"For the period of (?P<start_month>[A-Za-z]+) \d+\s*-\s*(?P<end_month>[A-Za-z]+\s+)?(?P<day>\d+), (?P<year>\d{4})",
        text,
    )
    if not match:
        raise ValueError("Could not find the DA publication period")
    month = (match.group("end_month") or match.group("start_month")).strip()
    return datetime.strptime(
        f"{month} {match.group('day')} {match.group('year')}", "%B %d %Y"
    ).date().isoformat()


def extract_price(text, label):
    for line in text.splitlines():
        if not line.strip().lower().startswith(label.lower()):
            continue
        values = re.findall(r"\d+(?:\.\d+)?", line)
        if len(values) >= 2:
            return float(values[-2]), "per piece" if "egg" in label.lower() else "per kg"
    return None


def sync():
    imported_count = 0
    skipped_reports = []
    reports = weekly_links()
    if not reports:
        raise RuntimeError("No official DA-4A Bantay Presyo reports were found")

    init_db()
    with sqlite3.connect(DB_PATH) as conn:
        existing_dates = {
            row[0] for row in conn.execute("SELECT DISTINCT date FROM prices")
        }
    for url, published_label in reports:
        published_date = datetime.strptime(published_label, "%B %d, %Y").date().isoformat()
        if published_date in existing_dates:
            print(f"Skipping existing DA report {published_label}.", flush=True)
            continue
        if published_label in SKIP_REPORT_LABELS:
            skipped_reports.append(f"{published_label}: source PDF is unreadable")
            print(f"Skipping unreadable DA report {published_label}.", flush=True)
            continue
        print(f"Processing DA report {published_label}...", flush=True)
        try:
            file_id = re.search(r"/d/([^/]+)", url).group(1)
            download_url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
            reader = PdfReader(BytesIO(download(download_url)))
            text = "\n".join(page.extract_text() or "" for page in reader.pages)
            record_date = observation_date(text)
        except Exception as error:
            skipped_reports.append(f"{published_label}: {error}")
            continue
        report_observations = []
        for commodity, (category, label) in COMMODITIES.items():
            result = extract_price(text, label)
            if result is None:
                continue
            price, unit = result
            report_observations.append(
                (record_date, commodity, price, category, unit, SOURCE, url, COVERAGE)
            )

        for observation in report_observations:
            insert_price(*observation)
        imported_count += len(report_observations)

    if not imported_count:
        if existing_dates:
            print("No new official DA observations were available.")
            return 0
        raise RuntimeError("Official DA publications contained no recognized commodity rows")

    print(f"Imported {imported_count} official DA observations from {SOURCE} ({COVERAGE}).")
    if skipped_reports:
        print(f"Skipped {len(skipped_reports)} reports with unreadable dates:")
        for report in skipped_reports:
            print(f"- {report}")
    return imported_count


if __name__ == "__main__":
    sync()