#!/usr/bin/env python3
"""Search PDF bank statements for specific merchant/subscription names."""

import pdfplumber
import os
from pathlib import Path
import sys

def search_pdfs(search_term, base_path="F:\\OneDrive\\Documents\\Budget\\Statements"):
    """Search all PDF files in bank statements for a term."""
    
    base = Path(base_path)
    results = []
    
    # Find all PDFs
    pdfs = list(base.rglob("*.pdf"))
    
    if not pdfs:
        print(f"No PDF files found in {base_path}")
        return results
    
    print(f"Found {len(pdfs)} PDF files. Searching for '{search_term}'...\n")
    
    for pdf_path in sorted(pdfs):
        try:
            with pdfplumber.open(pdf_path) as pdf:
                for page_num, page in enumerate(pdf.pages, 1):
                    # Extract text from page
                    text = page.extract_text()
                    
                    # Search for term (case-insensitive)
                    if search_term.lower() in text.lower():
                        # Extract tables if available (useful for transaction tables)
                        tables = page.extract_tables()
                        
                        results.append({
                            'file': str(pdf_path),
                            'page': page_num,
                            'found_in_text': True,
                            'tables': tables
                        })
                        
                        print(f"✓ Found in: {pdf_path.name}")
                        print(f"  Page: {page_num}")
                        
                        # Print context around the match, including following lines
                        lines = text.split('\n')
                        for i, line in enumerate(lines):
                            if search_term.lower() in line.lower():
                                print(f"  Context: {line}")
                                # USAA statements often have a two-line format (amount/details on the next line)
                                for j in range(1, 3):
                                    if i + j < len(lines):
                                        next_line = lines[i + j].strip()
                                        if next_line:
                                            print(f"  Next{j}: {next_line}")
                        print()

                        # Also search within extracted tables for precise row-level matches
                        if tables:
                            for ti, table in enumerate(tables):
                                try:
                                    for ri, row in enumerate(table):
                                        # Some cells can be None; normalize to strings
                                        cells = [str(c) if c is not None else '' for c in row]
                                        row_text = ' | '.join(cells)
                                        if search_term.lower() in row_text.lower():
                                            print(f"  Table {ti+1} Row {ri+1}: {row_text}")
                                    print()
                                except Exception:
                                    # Safeguard against malformed table structures
                                    pass
        except Exception as e:
            print(f"✗ Error reading {pdf_path.name}: {e}")
    
    return results


if __name__ == "__main__":
    search_term = sys.argv[1] if len(sys.argv) > 1 else "New Yorker"
    
    results = search_pdfs(search_term)
    
    if results:
        print(f"\nFound {len(results)} PDF(s) with '{search_term}'")
    else:
        print(f"\nNo PDFs found containing '{search_term}'")
