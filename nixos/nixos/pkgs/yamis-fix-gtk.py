#!/usr/bin/env python3
"""Recolor YAMIS ColorScheme-Text GTK fallback hex."""

from __future__ import annotations

import re
import sys
from pathlib import Path

UPSTREAM_FALLBACK = "#d8dee9"


def main() -> None:
    theme = Path(sys.argv[1])
    fallback = sys.argv[2] if len(sys.argv) > 2 else UPSTREAM_FALLBACK
    if not re.fullmatch(r"#[0-9a-fA-F]{3,8}", fallback):
        raise SystemExit(f"invalid fallback color: {fallback!r}")
    if fallback.lower() == UPSTREAM_FALLBACK.lower():
        return

    for svg in theme.rglob("*.svg"):
        data = svg.read_text(errors="ignore")
        updated = re.sub(re.escape(UPSTREAM_FALLBACK), fallback, data, flags=re.I)
        if updated != data:
            svg.write_text(updated)


if __name__ == "__main__":
    main()
