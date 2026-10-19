"""Read-only source audit, using the Python standard library. Not app runtime code."""
import argparse
from datetime import datetime
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import time
from urllib.request import Request, urlopen

BASE = "https://www.salaahtimes.co.uk"


class Node:
    def __init__(self, tag="root", attrs=(), parent=None):
        self.tag, self.attrs, self.parent = tag, dict(attrs), parent
        self.children = []

    @property
    def text(self):
        return " ".join("".join(c.text if isinstance(c, Node) else c for c in self.children).split())

    def all(self, tag=None, **attrs):
        found = []
        for child in self.children:
            if isinstance(child, Node):
                if (tag is None or child.tag == tag) and all(child.attrs.get(k) == v for k, v in attrs.items()):
                    found.append(child)
                found.extend(child.all(tag, **attrs))
        return found


class DOM(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.root = self.current = Node()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.current)
        self.current.children.append(node)
        if tag not in {"meta", "link", "img", "hr", "br", "input", "source", "wbr", "area", "base", "embed", "param", "track"}:
            self.current = node

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)

    def handle_endtag(self, tag):
        node = self.current
        while node.parent is not None:
            if node.tag == tag:
                self.current = node.parent
                return
            node = node.parent

    def handle_data(self, text):
        self.current.children.append(text)


def fetch(path):
    request = Request(BASE + path, headers={"User-Agent": "PrayerTimeSourceAudit/1.0"})
    with urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8-sig")


def directory(html):
    root = DOM(html).root
    container = root.all(id="jamaat-times")[0]
    mosques = {}
    for link in container.all("a"):
        match = re.fullmatch(r"/Mosque/Details/(\d+)", link.attrs.get("href", ""))
        if match:
            mosques[int(match[1])] = link.text
    assert len(mosques) > 0, "No mosques found"
    return mosques


def audit(html):
    root = DOM(html).root
    result = {"tables": {}, "jummah": []}
    for key in ("jamaat-times", "beginning-times"):
        containers = root.all(id=key)
        if not containers:
            assert key == "beginning-times", "No jamaat table"
            continue
        rows = containers[0].all("tr")
        headers = [node.text for node in rows[0].all("th")]
        assert headers[0] == "Date", headers
        count, missing = 0, 0
        for row in rows[1:]:
            cells = row.all("td")
            if not cells:
                continue
            assert len(cells) == len(headers), (headers, [c.text for c in cells])
            assert re.fullmatch(r"\w{3} \d{1,2} \w{3}", cells[0].text), cells[0].text
            for cell in cells[1:]:
                if cell.text in ("", "-", "--", "—"):
                    missing += 1
                else:
                    assert re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", cell.text), cell.text
            count += 1
        result["tables"][key] = {"headers": headers, "days": count, "missing_cells": missing}
    for heading in root.all("h3"):
        if "jumu" not in heading.text.lower():
            continue
        siblings = heading.parent.children
        for sibling in siblings[siblings.index(heading) + 1:]:
            if isinstance(sibling, Node):
                if sibling.tag == "h3":
                    break
                if sibling.tag == "p":
                    result["jummah"].append(sibling.text)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--fixtures", action="store_true", help="Audit saved fixtures, without network")
    args = parser.parse_args()
    if args.fixtures:
        fixtures = Path(__file__).resolve().parents[1] / "Tests/PrayerTimeCoreTests/Fixtures"
        mosques = directory((fixtures / "directory.html").read_text(encoding="utf-8-sig"))
        result = audit((fixtures / "aisha.html").read_text(encoding="utf-8-sig"))
        print(json.dumps({"mosques": len(mosques), "aisha": result}, indent=2))
        return
    mosques = directory(fetch("/Timetable/TodaysTimes"))
    ids = list(mosques) if args.all else [i for i in (1, 2, 3, 18, 132) if i in mosques]
    results = []
    for mosque_id in ids:
        result = audit(fetch(f"/Mosque/Details/{mosque_id}"))
        result.update(id=mosque_id, name=mosques[mosque_id])
        results.append(result)
        time.sleep(0.3)
    print(json.dumps({"mosques": len(mosques), "audited": results}, indent=2))


if __name__ == "__main__":
    main()
