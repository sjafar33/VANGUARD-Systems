"""Read-only recheck of the eight bundled event rows against NASA's public table."""
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import json

URL = "https://ccmc.gsfc.nasa.gov/challenges/sep/events/"
ROOT = Path(__file__).resolve().parents[1]

class Rows(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self.row, self.cell = [], None, None
    def handle_starttag(self, tag, attrs):
        if tag == "tr": self.row = []
        elif tag in ("td", "th") and self.row is not None: self.cell = []
    def handle_data(self, data):
        if self.cell is not None: self.cell.append(data)
    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None

page = subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--max-time", "30", URL], check=True, capture_output=True).stdout
parser = Rows(); parser.feed(page.decode("utf-8"))
rows, correct_table = [], False
for row in parser.rows:
    if len(row) > 2 and "Operational Satellite" in row[1]:
        correct_table = ">10 MeV" in row[2] and "10 pfu" in row[2] and ">100" not in row[2]
    elif correct_table and len(row) >= 7 and row[1] == "GOES-13":
        rows.append(row)

def iso(s):
    if s == "N/A": return None
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")

package = json.loads((ROOT / "MoonbaseAcademy/Resources/Science/science_package.json").read_text())
checks = []
for event in package["events"]:
    # The page repeats some tables; collapse only byte-equivalent parsed rows.
    matching = list({tuple(row): row for row in rows if iso(row[2]) == event["thresholdCrossingUTC"]}.values())
    assert len(matching) == 1, (event["id"], "missing or ambiguous source row", len(matching))
    row = matching[0]
    comparisons = {"thresholdCrossingUTC": iso(row[2]), "peakUTC": iso(row[3]), "maxFluxPfu": float(row[4]), "endUTC": iso(row[5])}
    assert all(event[key] == value for key, value in comparisons.items()), (event["id"], comparisons)
    checks.append({"id": event["id"], "matched": True, "fields": comparisons})
result = {"checkedUTC": datetime.now(timezone.utc).isoformat(), "source": URL, "method": "Fetch official HTML; select GOES-13 >10 MeV / 10 pfu table rows; compare threshold, peak, end and maximum flux with bundled JSON.", "eventCount": len(checks), "allMatched": True, "events": checks}
(ROOT / "Submission/ccmc-source-check.json").write_text(json.dumps(result, indent=2)+"\n")
print(f"Matched all {len(checks)} event rows, four fields per row.")
