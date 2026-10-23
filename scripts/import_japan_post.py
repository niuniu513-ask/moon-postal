"""Fetch Japan Post UTF-8 national town data and produce strict MoonPostal TSV.

Python is only the data acquisition adapter. Indexing/resolution runs in MoonBit.
Raw and converted full snapshots stay in _build/data (excluded from publication).
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile
from datetime import datetime, timezone
import os
import tempfile

URL = "https://www.post.japanpost.jp/service/search/zipcode/download/utf/zip/utf_ken_all.zip"
HEADER = "country\tpostal\tarea\tcity\ttown\tcoverage\n"


def convert(raw: bytes) -> tuple[list[tuple[str, ...]], dict]:
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        files = [n for n in archive.namelist() if n.lower().endswith('.csv')]
        if len(files) != 1:
            raise ValueError("expected exactly one CSV in official archive")
        text = archive.read(files[0]).decode("utf-8-sig")
    rows = []
    for number, fields in enumerate(csv.reader(io.StringIO(text)), 1):
        if len(fields) != 15 or len(fields[2]) != 7 or not fields[2].isascii() or not fields[2].isdigit():
            raise ValueError(f"invalid Japan Post row {number}")
        if any(x not in ('0', '1') for x in fields[9:13]) or fields[13] not in ('0', '1'):
            raise ValueError(f"unexpected flags or retired record at row {number}")
        town = fields[8]
        # Fallback town labels are routing notes, not actual town names.
        coverage = "exact"
        if any(marker in town for marker in ('以下に掲載がない場合', '一円')):
            coverage = "unspecified"
        elif fields[9] == '1' or any(marker in town for marker in ('（', '(', 'その他', '次のビル')):
            coverage = "conditional"
        row = ('JP', fields[2], fields[6], fields[7], town, coverage)
        if any(not x or any(ord(c) < 32 or ord(c) == 127 for c in x) for x in row):
            raise ValueError(f"empty/control-character field at row {number}")
        rows.append(row)
    unique = list(dict.fromkeys(rows))
    if not unique:
        raise ValueError("empty Japan Post snapshot")
    return unique, {
        "source_url": URL,
        "format_description": "https://www.post.japanpost.jp/zipcode/dl/utf-zip.html",
        "archive_sha256": hashlib.sha256(raw).hexdigest(),
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_rows": len(rows), "unique_rows": len(unique),
        "postal_codes": len({r[1] for r in unique}),
        "prefectures": len({r[2] for r in unique}),
        "coverage": {k: sum(r[5] == k for r in unique) for k in ('exact', 'unspecified', 'conditional')},
        "boundary": "Town routing only; excludes dedicated business codes and building existence. Conditional/fallback rows never auto-resolve.",
    }


def install_snapshot(raw: bytes, output: Path) -> dict:
    """Validate first, then replace each file atomically. Publish TSV last.

    The three files are not a multi-file transaction. Readers must verify the
    TSV hash in the manifest; a mismatched pair must never be used together.
    """
    rows, metadata = convert(raw)
    content = (HEADER + ''.join('\t'.join(row) + '\n' for row in rows)).encode('utf-8')
    metadata['tsv_sha256'] = hashlib.sha256(content).hexdigest()
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = []
    try:
        for target, payload in [
            (output.with_suffix('.zip'), raw),
            (output.with_suffix('.json'), (json.dumps(metadata, ensure_ascii=False, indent=2) + '\n').encode('utf-8')),
            (output, content),
        ]:
            with tempfile.NamedTemporaryFile(dir=output.parent, prefix='.postal-', delete=False) as f:
                staged.append((Path(f.name), target))
                f.write(payload)
                f.flush()
                os.fsync(f.fileno())
        for temp, target in staged:
            os.replace(temp, target)
    finally:
        for temp, _ in staged:
            temp.unlink(missing_ok=True)
    return metadata


def verify_snapshot(output: Path) -> dict:
    metadata = json.loads(output.with_suffix('.json').read_text(encoding='utf-8'))
    for path, field in [(output, 'tsv_sha256'), (output.with_suffix('.zip'), 'archive_sha256')]:
        if hashlib.sha256(path.read_bytes()).hexdigest() != metadata[field]:
            raise ValueError(f"snapshot integrity mismatch: {path.name}")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='use an already downloaded official ZIP offline')
    parser.add_argument('--output', type=Path, default=Path('_build/data/jp.tsv'))
    parser.add_argument('--verify', action='store_true', help='verify stored ZIP and TSV against the manifest without network')
    args = parser.parse_args()
    if args.verify:
        metadata = verify_snapshot(args.output)
    else:
        raw = args.archive.read_bytes() if args.archive else urllib.request.urlopen(URL, timeout=60).read()
        metadata = install_snapshot(raw, args.output)
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
