#!/usr/bin/env python3
"""Find New Yorker/CONDENAST charges in PDFs and extract amount."""

import pdfplumber
from pathlib import Path
import re

def find_newyorker():
    base = Path("F:\\OneDrive\\Documents\\Budget\\Statements")
    pdfs = list(base.rglob("*.pdf"))
    
    print(f"Searching {len(pdfs)} PDFs for New Yorker/CONDENAST...\n")
    
    for pdf_path in sorted(pdfs):
        try:
            with pdfplumber.open(pdf_path) as pdf:
                for page_num, page in enumerate(pdf.pages, 1):
                    text = page.extract_text()
                    
                    if 'condenast' in text.lower() or 'newyorker' in text.lower():
                        print(f"✓ Found in: {pdf_path.name}")
                        print(f"  Path: {pdf_path}")
                        print(f"  Page: {page_num}\n")
                        
                        lines = text.split('\n')
                        for i, line in enumerate(lines):
                            if 'condenast' in line.lower() or 'newyorker' in line.lower():
                                print("  Context:")
                                for j in range(max(0, i-4), min(len(lines), i+5)):
                                    print(f"    {lines[j]}")
                                print()
                        
                        # Also try to extract tables
                        tables = page.extract_tables()
                        if tables:
                            for table_num, table in enumerate(tables):
                                for row in table:
                                    row_str = ' '.join(str(cell) for cell in row if cell)
                                    if 'condenast' in row_str.lower() or 'newyorker' in row_str.lower():
                                        print("  Table entry:")
                                        print(f"    {row}")
                                        print()
        except Exception as e:
            pass

if __name__ == "__main__":
    find_newyorker()
