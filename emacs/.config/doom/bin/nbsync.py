"""ipynb <-> `# %%` percent text for Emacs notebook buffers (lisp/+jupyter-cells.el),
and ipynb <-> Org notebooks with `jupyter-LANG' src blocks (lisp/+jupyter-org.el).

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

to-org:   stdin = {"ipynb": .ipynb JSON, "media": "./.ob-jupyter/", "min_lines": int}
          stdout = {"org": Org text, "files": [{"path": relative path, "b64": data}]}
          Markdown cells go through pandoc; code cells become src blocks whose
          outputs are written the way emacs-jupyter writes them (#+RESULTS:, a
          :RESULTS: drawer for several outputs, images as [[file:MEDIA/<sha1>.ext]]),
          so re-running a block replaces them. Emacs writes "files" (images and
          markdown attachments) next to the .org.
from-org: stdin = {"org": Org text where code cell i is the line NBSYNCCELL<i>,
                   "language": str, "old": .ipynb JSON or null,
                   "cells": [{"source": str, "outputs": [{"kind": "text"|"image"|
                              "html"|"latex"|"markdown", "text"|"mime"+"data"}]}]}
          stdout = .ipynb JSON (prose via pandoc to markdown, metadata and cell ids
          from "old" as in write).

Run with a Python that has jupytext + nbformat (the jupytext uv tool's python, or
`uv run --no-project --with jupytext python -I nbsync.py ...`). to-org and
from-org also need pandoc on PATH.
"""

import base64
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

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


def _finish(new, old, lang):
    """Give NEW the metadata of OLD (or defaults for LANG), reuse OLD's cell ids, validate."""
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
        if lang == "python":
            spec = {"display_name": "Python 3", "language": "python", "name": "python3"}
        else:
            spec = {"display_name": lang, "language": lang, "name": lang}
        new.metadata.setdefault("kernelspec", spec)
        new.metadata.setdefault("language_info", {"name": lang})
    _reuse_ids(new, old)
    try:
        nbformat.validate(new)
    except nbformat.ValidationError as e:
        print(f"nbsync: validation warning: {e.message}", file=sys.stderr)


def write():
    req = json.load(sys.stdin)
    old = nbformat.reads(req["old"], as_version=4) if req.get("old") else None
    lang = req.get("language") or (_language(old) if old is not None else "python")
    new = jupytext.reads(req["text"], fmt=_fmt(lang))

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
    # `python' here, not LANG: a percent buffer without an .ipynb was always Python.
    _finish(new, old, lang if old is not None else "python")
    sys.stdout.write(nbformat.writes(new))


# --- Org notebooks ----------------------------------------------------------

PLACEHOLDER = "NBSYNCCELL{}"
PLACEHOLDER_RE = re.compile(r"^NBSYNCCELL(\d+)$", re.M)

# emacs-jupyter's `jupyter-org-mime-types' order: images win over html.
ORG_MIMES = [
    "text/org", "image/svg+xml", "image/jpeg", "image/png",
    "text/html", "text/markdown", "text/latex", "text/plain",
]
IMAGE_EXT = {"image/svg+xml": "svg", "image/jpeg": "jpg", "image/png": "png"}
EXPORT_TYPE = {"text/html": "html", "text/markdown": "markdown", "text/latex": "latex"}
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def _pandoc(args, text, cwd=None):
    exe = shutil.which("pandoc")
    if exe is None:
        sys.exit("nbsync: pandoc not found on PATH")
    res = subprocess.run([exe, *args], input=text, capture_output=True, text=True,
                         encoding="utf-8", cwd=cwd)
    if res.returncode != 0:
        sys.exit(f"nbsync: pandoc failed: {res.stderr.strip()}")
    if res.stderr.strip():
        print(f"nbsync: pandoc: {res.stderr.strip()}", file=sys.stderr)
    return res.stdout


def _org_escape(text):
    """`org-escape-code-in-string': protect lines starting with `*' or `#+'."""
    return re.sub(r"(?m)^([ \t]*)(,*(?:\*|#\+))", r"\1,\2", text)


def _plain(text):
    """Terminal text as a file shows it: no ANSI codes, `\\r' progress bars at their last state."""
    text = ANSI_RE.sub("", text)
    lines = []
    for line in text.split("\n"):
        if "\r" in line:
            parts = [p for p in line.split("\r") if p]
            line = parts[-1] if parts else ""
        lines.append(line)
    return "\n".join(lines)


def _org_scalar(text, min_lines):
    """Fixed-width `: ' lines, or an example block from MIN_LINES lines on."""
    text = text.rstrip("\n")
    if text.count("\n") + 1 >= min_lines:
        return f"#+begin_example\n{_org_escape(text)}\n#+end_example"
    return "\n".join(f": {line}" if line else ":" for line in text.split("\n"))


def _org_results(outputs, media, min_lines, files):
    """Org text of a code cell's OUTPUTS (no `#+RESULTS:'), images added to FILES."""
    items = []  # [kind, text]; consecutive streams merge like emacs-jupyter's
    for out in outputs:
        otype = out.get("output_type")
        if otype == "stream":
            if items and items[-1][0] == "stream":
                items[-1][1] += out.get("text", "")
            else:
                items.append(["stream", out.get("text", "")])
        elif otype == "error":
            items.append(["text", "\n".join(out.get("traceback") or [])])
        elif otype in ("execute_result", "display_data"):
            data = out.get("data", {})
            mime = next((m for m in ORG_MIMES if m in data), None)
            if mime is None:
                continue
            value = data[mime]
            if not isinstance(value, str):
                value = json.dumps(value)
            if mime in IMAGE_EXT:
                if mime == "image/svg+xml":
                    b64 = base64.b64encode(value.encode("utf-8")).decode("ascii")
                    key = value
                else:
                    b64 = re.sub(r"\s+", "", value)
                    key = b64
                name = f"{hashlib.sha1(key.encode('utf-8')).hexdigest()}.{IMAGE_EXT[mime]}"
                path = f"{media.rstrip('/')}/{name}"
                files.setdefault(path, b64)
                items.append(["org", f"[[file:{path}]]"])
            elif mime == "text/org":
                items.append(["org", value.rstrip("\n")])
            elif mime in EXPORT_TYPE:
                kind = EXPORT_TYPE[mime]
                items.append(["org", f"#+begin_export {kind}\n{_org_escape(value.rstrip(chr(10)))}\n#+end_export"])
            else:
                items.append(["text", value])
    rendered = []
    for kind, text in items:
        if kind == "org":
            rendered.append(text)
        else:
            text = _plain(text).rstrip("\n")
            if text.strip():
                rendered.append(_org_scalar(text, min_lines))
    if not rendered:
        return None
    if len(rendered) == 1:
        return rendered[0]
    return ":RESULTS:\n" + "\n".join(rendered) + "\n:END:"


def _collect_files(root):
    """{relative path: base64} of every file under ROOT."""
    found = {}
    for dirpath, _dirs, names in os.walk(root):
        for name in names:
            full = os.path.join(dirpath, name)
            rel = "./" + os.path.relpath(full, root).replace(os.sep, "/")
            with open(full, "rb") as f:
                found[rel] = base64.b64encode(f.read()).decode("ascii")
    return found


def to_org():
    req = json.load(sys.stdin)
    nb = nbformat.reads(req["ipynb"], as_version=4)
    media = req.get("media") or "./.ob-jupyter/"
    min_lines = int(req.get("min_lines") or 10)
    lang = _language(nb)

    # Prose: code cells become placeholder paragraphs so pandoc never sees code.
    prose = copy.deepcopy(nb)
    code = []
    for i, cell in enumerate(prose.cells):
        if cell.cell_type == "code":
            prose.cells[i] = nbformat.v4.new_markdown_cell(PLACEHOLDER.format(len(code)))
            code.append(nb.cells[i])
    for cell in prose.cells:
        cell.pop("id", None)
    prose.nbformat_minor = 4
    with tempfile.TemporaryDirectory(prefix="nbsync-") as tmp:
        org = _pandoc(["-f", "ipynb-auto_identifiers", "-t", "org", "--wrap=preserve",
                       f"--extract-media={media}"],
                      nbformat.writes(prose), cwd=tmp)
        files = _collect_files(tmp)

    def block(m):
        cell = code[int(m.group(1))]
        src = cell.source.rstrip("\n")
        text = f"#+begin_src jupyter-{lang}\n{_org_escape(src)}\n#+end_src" if src else \
            f"#+begin_src jupyter-{lang}\n#+end_src"
        results = _org_results(cell.get("outputs") or [], media, min_lines, files)
        if results:
            text += f"\n\n#+RESULTS:\n{results}"
        return text

    seen = {int(i) for i in PLACEHOLDER_RE.findall(org)}
    org = PLACEHOLDER_RE.sub(block, org)
    missing = [i for i in range(len(code)) if i not in seen]
    if missing:
        print(f"nbsync: pandoc dropped code cells {missing}; appended at the end", file=sys.stderr)
        org = org.rstrip("\n") + "\n\n" + "\n\n".join(
            block(PLACEHOLDER_RE.match(PLACEHOLDER.format(i))) for i in missing) + "\n"
    files_out = [{"path": p, "b64": b} for p, b in files.items()]
    json.dump({"org": org, "files": files_out}, sys.stdout)


def _md_cells(markdown):
    """Markdown cells of a prose chunk: one per heading section (headings in fences don't count)."""
    cells, cur, fence = [], [], None
    for line in markdown.split("\n"):
        m = re.match(r"^\s*(`{3,}|~{3,})", line)
        if m:
            if fence is None:
                fence = m.group(1)
            elif m.group(1).startswith(fence):
                fence = None
        if fence is None and re.match(r"^#{1,6}\s", line) and "".join(cur).strip():
            cells.append("\n".join(cur))
            cur = []
        cur.append(line)
    if "".join(cur).strip():
        cells.append("\n".join(cur))
    return [c.strip("\n") for c in cells]


def _nb_output(out):
    kind = out.get("kind")
    if kind == "image":
        return nbformat.v4.new_output("display_data", data={out["mime"]: out["data"]})
    mime = {"html": "text/html", "latex": "text/latex", "markdown": "text/markdown"}.get(kind)
    if mime:
        return nbformat.v4.new_output("display_data", data={mime: out.get("text", "")})
    text = out.get("text", "")
    if text and not text.endswith("\n"):
        text += "\n"
    return nbformat.v4.new_output("stream", name="stdout", text=text)


def from_org():
    req = json.load(sys.stdin)
    old = nbformat.reads(req["old"], as_version=4) if req.get("old") else None
    lang = req.get("language") or "python"
    entries = req.get("cells") or []
    # Jupyter's markdown: $…$ / $$…$$ math and raw LaTeX environments (MathJax),
    # pipe tables, ``` fences. (gfm would write math as $`…`$.) H:6: pandoc, like
    # org export, turns headings below level 3 into list items, which would
    # indent the placeholders under them (a file's own #+OPTIONS still wins).
    md = _pandoc(["-f", "org", "--wrap=preserve", "-t",
                  "markdown_strict+tex_math_dollars+raw_tex+pipe_tables+strikeout"
                  "+backtick_code_blocks+fenced_code_blocks-raw_html"],
                 "#+OPTIONS: H:6\n" + (req.get("org") or ""))

    new = nbformat.v4.new_notebook()
    pos = 0
    # Indented placeholders (block inside a list) still become cells.
    for m in re.finditer(r"^[ \t]*NBSYNCCELL(\d+)[ \t]*$", md, re.M):
        for src in _md_cells(md[pos:m.start()]):
            new.cells.append(nbformat.v4.new_markdown_cell(src))
        i = int(m.group(1))
        entry = entries[i] if i < len(entries) else {}
        cell = nbformat.v4.new_code_cell(entry.get("source", ""))
        cell.outputs = [_nb_output(o) for o in entry.get("outputs") or []]
        new.cells.append(cell)
        pos = m.end()
    for src in _md_cells(md[pos:]):
        new.cells.append(nbformat.v4.new_markdown_cell(src))
    ncode = sum(c.cell_type == "code" for c in new.cells)
    if ncode != len(entries):
        print(f"nbsync: {len(entries)} src blocks but {ncode} code cells", file=sys.stderr)
    _finish(new, old, lang)
    sys.stdout.write(nbformat.writes(new))


if __name__ == "__main__":
    {"read": read, "write": write, "to-org": to_org, "from-org": from_org}[sys.argv[1]]()
