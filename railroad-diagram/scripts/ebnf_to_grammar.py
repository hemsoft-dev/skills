"""
EBNF-to-Grammar Converter — Parses a subset of EBNF notation into .grammar.json format.

Supports:
  rule = expression ;
  "terminal" | 'terminal'
  NonTerminal
  a , b           → Sequence
  a | b           → Choice
  [ optional ]    → Optional
  { repeatable }  → ZeroOrMore
  ( group )       → Grouping

Usage:
    python scripts/ebnf_to_grammar.py input.ebnf --title "My Grammar" --output grammars/my.grammar.json
    python scripts/ebnf_to_grammar.py input.ebnf  # prints to stdout
"""

import json
import re
import sys
from pathlib import Path


class EBNFParser:
    """Simple recursive-descent EBNF parser."""

    def __init__(self, text):
        self.text = text
        self.pos = 0

    def _skip_ws(self):
        while self.pos < len(self.text) and self.text[self.pos] in ' \t\n\r':
            self.pos += 1

    def _peek(self):
        self._skip_ws()
        if self.pos >= len(self.text):
            return None
        return self.text[self.pos]

    def _expect(self, ch):
        self._skip_ws()
        if self.pos < len(self.text) and self.text[self.pos] == ch:
            self.pos += 1
            return True
        return False

    def _read_string(self, quote):
        self.pos += 1  # skip opening quote
        start = self.pos
        while self.pos < len(self.text) and self.text[self.pos] != quote:
            self.pos += 1
        if self.pos >= len(self.text):
            raise SyntaxError(f"Unterminated string starting at position {start - 1}")
        result = self.text[start:self.pos]
        self.pos += 1  # skip closing quote
        return result

    def _read_identifier(self):
        self._skip_ws()
        start = self.pos
        while self.pos < len(self.text) and (self.text[self.pos].isalnum() or self.text[self.pos] in '_-'):
            self.pos += 1
        return self.text[start:self.pos]

    def parse(self):
        """Parse all rules and return a dict of rule_name → grammar node."""
        rules = {}
        while self.pos < len(self.text):
            self._skip_ws()
            if self.pos >= len(self.text):
                break
            # Skip comments
            if self.text[self.pos] == '(' and self.pos + 1 < len(self.text) and self.text[self.pos + 1] == '*':
                end = self.text.find('*)', self.pos + 2)
                self.pos = end + 2 if end >= 0 else len(self.text)
                continue
            name = self._read_identifier()
            if not name:
                self.pos += 1
                continue
            self._skip_ws()
            if not self._expect('='):
                continue
            expr = self._parse_alternation()
            self._expect(';')
            rules[name] = expr
        return rules

    def _parse_alternation(self):
        items = [self._parse_sequence()]
        while self._peek() == '|':
            self.pos += 1
            items.append(self._parse_sequence())
        if len(items) == 1:
            return items[0]
        return {"type": "Choice", "default": 0, "items": items}

    def _parse_sequence(self):
        items = [self._parse_atom()]
        while self._peek() == ',':
            self.pos += 1
            items.append(self._parse_atom())
        if len(items) == 1:
            return items[0]
        return {"type": "Sequence", "items": items}

    def _parse_atom(self):
        self._skip_ws()
        ch = self._peek()

        if ch == '"' or ch == "'":
            s = self._read_string(ch)
            return {"type": "Terminal", "label": s}

        if ch == '[':
            self.pos += 1
            inner = self._parse_alternation()
            self._expect(']')
            return {"type": "Optional", "items": [inner], "skip": True}

        if ch == '{':
            self.pos += 1
            inner = self._parse_alternation()
            self._expect('}')
            return {"type": "ZeroOrMore", "items": [inner]}

        if ch == '(':
            self.pos += 1
            inner = self._parse_alternation()
            self._expect(')')
            return inner

        # Must be an identifier (NonTerminal)
        ident = self._read_identifier()
        if ident:
            return {"type": "NonTerminal", "label": ident}

        # Skip unknown char
        self.pos += 1
        return {"type": "Terminal", "label": "?"}


def ebnf_to_grammar(ebnf_text, title="Untitled Grammar", description="", source=""):
    """Convert EBNF text into a .grammar.json structure."""
    parser = EBNFParser(ebnf_text)
    rules = parser.parse()
    return {
        "meta": {
            "title": title,
            "description": description,
            "source": source,
            "version": "auto"
        },
        "rules": {name: {"definition": defn} for name, defn in rules.items()}
    }


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_path = sys.argv[1]
    title = "Untitled Grammar"
    output_path = None

    for i, arg in enumerate(sys.argv):
        if arg == "--title" and i + 1 < len(sys.argv):
            title = sys.argv[i + 1]
        if arg == "--output" and i + 1 < len(sys.argv):
            output_path = sys.argv[i + 1]

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            ebnf_text = f.read()
    except FileNotFoundError:
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    grammar = ebnf_to_grammar(ebnf_text, title=title)
    result = json.dumps(grammar, indent=2, ensure_ascii=False)

    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(result)
        print(f"Generated: {output_path}")
    else:
        print(result)


if __name__ == "__main__":
    main()
