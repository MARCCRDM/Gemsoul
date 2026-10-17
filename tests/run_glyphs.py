"""No text the game shows uses a glyph that Roblox's Gotham can't draw.

These showed in game as empty boxes. Comments may name them; strings may
not. Draw the shape instead (IronUi.cross for an X, a turned "›" for an
arrow), or use one that renders: › ‹ ◆ ✓ ·
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LONG = re.compile(r"\[(=*)\[")  # a --[[ ]] (or --[==[ ]==]) comment
BOXES = {
    "✕": "MULTIPLICATION X",
    "▾": "SMALL DOWN TRIANGLE",
    "▴": "SMALL UP TRIANGLE",
    "◂": "SMALL LEFT TRIANGLE",
    "▸": "SMALL RIGHT TRIANGLE",
    "↻": "CLOCKWISE ARROW",
}


def code_spans(text):
    """Yields (line number, character) for every character outside a comment."""
    i, line, n = 0, 1, len(text)
    quote = None
    while i < n:
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote or ch == "\n" and quote != "`":
                quote = None
        elif text.startswith("--", i):
            long = LONG.match(text, i + 2)
            if long:
                close = "]" + long.group(1) + "]"
                end = text.find(close, i)
                end = n if end < 0 else end + len(close)
                line += text.count("\n", i, end)
                i = end
                continue
            end = text.find("\n", i)
            i = n if end < 0 else end
            continue
        elif ch in "\"'`":
            quote = ch
        if ch == "\n":
            line += 1
        else:
            yield line, ch
        i += 1


found = []
files = sorted((ROOT / "src").rglob("*.luau"))
for path in files:
    for line, ch in code_spans(path.read_text(encoding="utf-8")):
        if ch in BOXES:
            found.append(f"{path.relative_to(ROOT)}:{line}: {ch} ({BOXES[ch]}) shows as an empty box in game")
assert not found, "\n".join(found)
print(f"PASS: no glyph that shows as a box, in {len(files)} source files")
