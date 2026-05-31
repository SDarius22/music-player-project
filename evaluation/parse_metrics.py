#!/usr/bin/env python3
"""Pull timing metrics out of Flutter logs."""

from __future__ import annotations

import argparse
import csv
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


TIMESTAMP_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2}T[\d:.]+)")
METRIC_RE = re.compile(
    r"\[METRIC\].*?\b(?P<name>[a-z_]+_ms)\s*=\s*(?P<value>[0-9]+(?:\.[0-9]+)?)",
    re.IGNORECASE,
)
CONTEXT_RE = re.compile(r"\b(?P<key>song|peer)\s*=\s*(?P<value>.+?)\s*$")


@dataclass(frozen=True)
class MetricRow:
    label: str
    timestamp: str
    metric: str
    value_ms: float
    context: str

    def csv_row(self) -> dict[str, str | float]:
        return {
            "label": self.label,
            "timestamp": self.timestamp,
            "metric": self.metric,
            "value_ms": self.value_ms,
            "context": self.context,
        }


def percentile(values: Iterable[float], pct: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return float("nan")
    if len(ordered) == 1:
        return ordered[0]

    rank = (pct / 100.0) * (len(ordered) - 1)
    lo = math.floor(rank)
    hi = math.ceil(rank)
    if lo == hi:
        return ordered[lo]
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (rank - lo)


def parse_line(line: str, label: str) -> MetricRow | None:
    metric_match = METRIC_RE.search(line)
    if metric_match is None:
        return None

    timestamp_match = TIMESTAMP_RE.search(line)
    context_match = CONTEXT_RE.search(line)
    context = ""
    if context_match is not None:
        context = f"{context_match.group('key')}={context_match.group('value')}"

    return MetricRow(
        label=label,
        timestamp=timestamp_match.group(1) if timestamp_match else "",
        metric=metric_match.group("name").lower(),
        value_ms=float(metric_match.group("value")),
        context=context,
    )


def read_log(path: Path, label: str) -> list[MetricRow]:
    rows: list[MetricRow] = []
    with path.open("r", errors="replace") as handle:
        for line in handle:
            row = parse_line(line, label)
            if row is not None:
                rows.append(row)
    return rows


def label_for(path: Path, args: argparse.Namespace) -> str:
    if args.label is not None:
        return args.label
    if args.label_from_filename:
        return path.stem
    return ""


def collect_rows(args: argparse.Namespace) -> list[MetricRow]:
    rows: list[MetricRow] = []
    for path in args.logs:
        if not path.exists():
            print(f"warning: {path} not found, skipping", file=sys.stderr)
            continue
        rows.extend(read_log(path, label_for(path, args)))
    return rows


def write_csv(rows: list[MetricRow], out: Path | None) -> None:
    fieldnames = ["label", "timestamp", "metric", "value_ms", "context"]
    handle = out.open("w", newline="") if out else sys.stdout
    try:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(row.csv_row() for row in rows)
    finally:
        if out:
            handle.close()
            print(f"wrote {len(rows)} rows to {out}", file=sys.stderr)


def print_summary(rows: list[MetricRow]) -> None:
    groups: dict[tuple[str, str], list[float]] = {}
    for row in rows:
        groups.setdefault((row.label, row.metric), []).append(row.value_ms)

    print("\n== Summary (ms) ==", file=sys.stderr)
    header = f"{'label':<16}{'metric':<16}{'n':>4}{'median':>10}{'p75':>10}{'p95':>10}{'min':>10}{'max':>10}"
    print(header, file=sys.stderr)
    print("-" * len(header), file=sys.stderr)

    for (label, metric), values in sorted(groups.items()):
        print(
            f"{(label or '-'):<16}{metric:<16}{len(values):>4}"
            f"{percentile(values, 50):>10.1f}"
            f"{percentile(values, 75):>10.1f}"
            f"{percentile(values, 95):>10.1f}"
            f"{min(values):>10.1f}{max(values):>10.1f}",
            file=sys.stderr,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract [METRIC] *_ms values from Flutter logs.",
    )
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("-o", "--out", type=Path, help="CSV output path; defaults to stdout")
    parser.add_argument("--label", help="label to use for every row")
    parser.add_argument(
        "--label-from-filename",
        action="store_true",
        help="use each log file stem as the CSV label",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    rows = collect_rows(args)
    if not rows:
        print("no [METRIC] lines found", file=sys.stderr)
        return 1

    write_csv(rows, args.out)
    print_summary(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
