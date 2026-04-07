"""
Railroad Diagram Generator — Converts JSON grammar definitions to SVG railroad diagrams.

Uses tabatkins/railroad-diagrams (MIT) for rendering.
Input:  JSON grammar file (see grammars/ for examples)
Output: SVG file(s) in output/

Usage:
    python scripts/generate.py grammars/agent-md.grammar.json
    python scripts/generate.py grammars/agent-md.grammar.json --output output/agent-md.svg
    python scripts/generate.py grammars/ --all
"""

import json
import sys
import os
from pathlib import Path

import railroad as rr


# ---------------------------------------------------------------------------
# JSON grammar → railroad objects
# ---------------------------------------------------------------------------

def _build(node):
    """Recursively convert a JSON grammar node into a railroad DiagramItem."""
    if isinstance(node, str):
        # Bare string → Terminal
        return rr.Terminal(node)

    if isinstance(node, list):
        # Bare list → Sequence
        return rr.Sequence(*[_build(n) for n in node])

    kind = node.get("type", "Terminal")
    label = node.get("label", "")
    items = node.get("items", [])
    repeat = node.get("repeat")
    skip = node.get("skip", False)
    default = node.get("default")

    if kind == "Terminal":
        return rr.Terminal(label)

    if kind == "NonTerminal":
        return rr.NonTerminal(label)

    if kind == "Sequence":
        return rr.Sequence(*[_build(i) for i in items])

    if kind == "Choice":
        default_idx = default if default is not None else 0
        return rr.Choice(default_idx, *[_build(i) for i in items])

    if kind == "Optional":
        if not items and not label:
            raise ValueError("Optional node must have 'items' or 'label'")
        inner = _build(items[0]) if items else _build(label)
        return rr.Optional(inner, skip=skip)

    if kind == "OneOrMore":
        if not items:
            raise ValueError("OneOrMore node must have at least one item")
        body = _build(items[0])
        sep = _build(items[1]) if len(items) > 1 else None
        if sep:
            return rr.OneOrMore(body, sep)
        return rr.OneOrMore(body)

    if kind == "ZeroOrMore":
        if not items:
            raise ValueError("ZeroOrMore node must have at least one item")
        body = _build(items[0])
        sep = _build(items[1]) if len(items) > 1 else None
        if sep:
            return rr.ZeroOrMore(body, sep)
        return rr.ZeroOrMore(body)

    if kind == "Group":
        inner = _build(items[0]) if items else rr.Skip()
        return rr.Group(inner, label=label)

    if kind == "Comment":
        return rr.Comment(label)

    if kind == "Stack":
        return rr.Stack(*[_build(i) for i in items])

    if kind == "HorizontalChoice":
        return rr.HorizontalChoice(*[_build(i) for i in items])

    if kind == "Skip":
        return rr.Skip()

    raise ValueError(f"Unknown node type: {kind}")


def generate_diagram(rule_name, rule_def):
    """Build a Diagram object from a single grammar rule."""
    inner = _build(rule_def)
    return rr.Diagram(inner, type="complex")


# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

def load_grammar(path):
    """Load a .grammar.json file and return (metadata, rules)."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e
    meta = data.get("meta", {})
    rules = data.get("rules", {})
    if not isinstance(rules, dict):
        raise ValueError(f"'rules' must be a dict in {path}")
    return meta, rules


def render_to_svg(grammar_path, output_path=None):
    """Render all rules in a grammar file to a single combined SVG/HTML file."""
    meta, rules = load_grammar(grammar_path)
    grammar_name = meta.get("title", Path(grammar_path).stem)

    if output_path is None:
        output_dir = Path(__file__).resolve().parent.parent / "output"
        output_dir.mkdir(exist_ok=True)
        stem = Path(grammar_path).stem.replace(".grammar", "")
        output_path = output_dir / f"{stem}.html"

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    parts = []
    parts.append(f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{_html_escape(grammar_name)} — Railroad Diagrams</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem; color: #1a1a1a; background: #fafafa; }}
  h1 {{ border-bottom: 2px solid #333; padding-bottom: 0.5rem; }}
  h2 {{ margin-top: 2rem; color: #333; }}
  .description {{ color: #666; margin-bottom: 0.5rem; font-style: italic; }}
  .diagram-container {{ background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin: 0.5rem 0 1.5rem; overflow-x: auto; }}
  svg.railroad-diagram {{ background-color: transparent; }}
  svg.railroad-diagram path {{ stroke-width: 3; stroke: #333; fill: none; }}
  svg.railroad-diagram text {{ font: bold 14px monospace; text-anchor: middle; }}
  svg.railroad-diagram text.label {{ text-anchor: start; }}
  svg.railroad-diagram text.comment {{ font: italic 12px monospace; }}
  svg.railroad-diagram rect {{ stroke-width: 3; stroke: #333; fill: #dbeafe; }}
  svg.railroad-diagram rect.group-box {{ stroke: #999; stroke-dasharray: 10 5; fill: #f3f4f6; }}
  svg.railroad-diagram .non-terminal rect {{ fill: #fef3c7; }}
  svg.railroad-diagram .terminal rect {{ fill: #dbeafe; }}
</style>
</head>
<body>
<h1>{_html_escape(grammar_name)}</h1>
""")

    if meta.get("description"):
        parts.append(f'<p class="description">{_html_escape(meta["description"])}</p>\n')

    if meta.get("source"):
        parts.append(f'<p>Source: <a href="{_html_escape(meta["source"])}">{_html_escape(meta["source"])}</a></p>\n')

    for rule_name, rule_def in rules.items():
        # Rule can have a description alongside the definition
        description = None
        definition = rule_def
        if isinstance(rule_def, dict) and "description" in rule_def and "definition" in rule_def:
            description = rule_def["description"]
            definition = rule_def["definition"]

        diagram = generate_diagram(rule_name, definition)

        parts.append(f"<h2>{_html_escape(rule_name)}</h2>\n")
        if description:
            parts.append(f'<p class="description">{_html_escape(description)}</p>\n')
        parts.append('<div class="diagram-container">\n')

        from io import StringIO
        buf = StringIO()
        diagram.writeSvg(buf.write)
        parts.append(buf.getvalue())

        parts.append("\n</div>\n")

    parts.append("</body>\n</html>\n")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("".join(parts))

    return str(output_path)


def _html_escape(text):
    """Minimal HTML escaping."""
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = None

    # Parse --output flag
    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        if idx + 1 < len(sys.argv):
            output_path = sys.argv[idx + 1]

    # Process --all flag (render all grammars in a directory)
    if "--all" in sys.argv:
        grammar_dir = Path(input_path)
        if not grammar_dir.is_dir():
            print(f"Error: {input_path} is not a directory")
            sys.exit(1)
        for gf in sorted(grammar_dir.glob("*.grammar.json")):
            result = render_to_svg(str(gf))
            print(f"Generated: {result}")
        return

    # Single file
    if not os.path.isfile(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)

    result = render_to_svg(input_path, output_path)
    print(f"Generated: {result}")


if __name__ == "__main__":
    main()
