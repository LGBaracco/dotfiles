"""ipynb <-> `# %%` percent text for Emacs notebook buffers (lisp/+jupyter-cells.el).

read:  stdin = .ipynb JSON
       stdout = {"text": percent text (no jupytext header), "language": str,
                 "cells": [{"execution_count": int|null, "outputs": [...]}, ...]}
       ("cells" has one entry per *code* cell, in order.)
write: stdin = {"text": percent text, "language": str, "old": .ipynb JSON or null,
                "cells": [null | {"execution_count": int|null, "outputs": [...]}, ...]}
       stdout = .ipynb JSON. Notebook metadata (kernelspec, language_info, ...) comes
       from "old"; code cell i gets cells[i] (null = no outputs), so the file holds
       exactly the outputs shown in Emacs. Cell ids are reused from "old" (same
       index and type, else same source) to keep git diffs small.

Run with a Python that has jupytext + nbformat (the jupytext uv tool's python, or
`uv run --no-project --with jupytext python -I nbsync.py ...`).
"""

import json
import sys

import jupytext
import nbformat

PERCENT = {
    "extension": ".py",
    "format_name": "percent",
    # The header (kernelspec etc.) stays in the .ipynb; Emacs shows only cells.
    "notebook_metadata_filter": "-all",
}


EXTENSIONS = {"python": ".py", "julia": ".jl", "r": ".R", "R": ".R", "bash": ".sh"}


def _fmt(lang):
    return dict(PERCENT, extension=EXTENSIONS.get(lang, ".py"))


def _language(nb):
    md = nb.get("metadata", {})
    return (
        md.get("kernelspec", {}).get("language")
        or md.get("language_info", {}).get("name")
        or md.get("jupytext", {}).get("main_language")
        or "python"
    )


def read():
    nb = nbformat.reads(sys.stdin.read(), as_version=4)
    lang = _language(nb)
    text = jupytext.writes(nb, fmt=_fmt(lang))
    cells = [
        {"execution_count": c.get("execution_count"), "outputs": c.get("outputs", [])}
        for c in nb.cells
        if c.cell_type == "code"
    ]
    json.dump({"text": text, "language": lang, "cells": cells}, sys.stdout)


def _reuse_ids(new, old):
    used = set()
    old_cells = old.cells if old is not None else []
    for i, cell in enumerate(new.cells):
        match = None
        if i < len(old_cells) and old_cells[i].cell_type == cell.cell_type:
            match = old_cells[i]
        else:
            for oc in old_cells:
                if id(oc) not in used and oc.cell_type == cell.cell_type and oc.source == cell.source:
                    match = oc
                    break
        if match is not None and id(match) not in used and "id" in match:
            used.add(id(match))
            cell["id"] = match["id"]
            if cell.cell_type == "markdown" and "attachments" in match:
                cell["attachments"] = match["attachments"]


def write():
    req = json.load(sys.stdin)
    old = nbformat.reads(req["old"], as_version=4) if req.get("old") else None
    lang = req.get("language") or (_language(old) if old is not None else "python")
    new = jupytext.reads(req["text"], fmt=_fmt(lang))
    if old is not None:
        md = dict(old.metadata)
        md.pop("jupytext", None)
        new.metadata = nbformat.from_dict(md)
        # Keep the file's schema version: cell ids exist only from 4.5 on.
        new.nbformat_minor = old.nbformat_minor
        if old.nbformat_minor < 5:
            for cell in new.cells:
                cell.pop("id", None)
    else:
        new.metadata.pop("jupytext", None)
        new.metadata.setdefault(
            "kernelspec", {"display_name": "Python 3", "language": "python", "name": "python3"}
        )
        new.metadata.setdefault("language_info", {"name": "python"})
    _reuse_ids(new, old)

    entries = req.get("cells") or []
    code = [c for c in new.cells if c.cell_type == "code"]
    if len(entries) > len(code):
        print(f"nbsync: {len(entries)} outputs for {len(code)} code cells", file=sys.stderr)
    for i, cell in enumerate(code):
        entry = entries[i] if i < len(entries) else None
        if entry:
            cell.outputs = [nbformat.from_dict(o) for o in entry.get("outputs") or []]
            cell.execution_count = entry.get("execution_count")
        else:
            cell.outputs = []
            cell.execution_count = None
    try:
        nbformat.validate(new)
    except nbformat.ValidationError as e:
        print(f"nbsync: validation warning: {e.message}", file=sys.stderr)
    sys.stdout.write(nbformat.writes(new))


if __name__ == "__main__":
    {"read": read, "write": write}[sys.argv[1]]()
