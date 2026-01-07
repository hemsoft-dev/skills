#!/usr/bin/env python3
"""
normalize-chase.py
Normalizes Chase Credit Card CSVs using GitHub Copilot CLI
Uses temp files to avoid prompt escaping issues.
"""

import subprocess
import tempfile
import os
from pathlib import Path
from collections import defaultdict

STATEMENTS_ROOT = Path(r"F:\OneDrive\Documents\Budget\Statements")
ACCOUNT_NAME = "Chase Credit Card"
ACCOUNT_ROOT = STATEMENTS_ROOT / ACCOUNT_NAME
YEAR_FOLDER = ACCOUNT_ROOT / "2025"
CATEGORY_FILE = STATEMENTS_ROOT / "category-choices.txt"

def get_categories():
    return CATEGORY_FILE.read_text(encoding='utf-8')

def normalize_csv(csv_path, account_name, categories):
    """Call copilot CLI to normalize a CSV file using temp file for prompt."""
    csv_content = csv_path.read_text(encoding='utf-8')
    
    prompt = f"""Convert to normalized CSV. Only output CSV lines, no markdown fences.
Header: Date,Account,Category,Description,Amount
YYYY-MM-DD dates. Negative=expense. Payments POSITIVE as Credit Card Payment.
Account: {account_name}
Categories: {categories}

CSV:
{csv_content}"""
    
    # Write prompt to temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as f:
        f.write(prompt)
        prompt_file = f.name
    
    try:
        # Use echo with piping 
        result = subprocess.run(
            f'type "{prompt_file}" | copilot --model claude-haiku-4.5',
            capture_output=True,
            text=True,
            shell=True,
            encoding='utf-8',
            timeout=120
        )
        output = result.stdout
        if result.returncode != 0:
            print(f"  stderr: {result.stderr[:200]}")
    except subprocess.TimeoutExpired:
        print("  TIMEOUT!")
        output = ""
    finally:
        os.unlink(prompt_file)
    
    # Extract only lines that look like normalized data (YYYY-MM-DD format)
    lines = []
    for line in output.split('\n'):
        line = line.strip()
        if line and len(line) > 10 and line[0:4].isdigit() and line[4] == '-' and line[7] == '-':
            lines.append(line)
    
    return lines

def main():
    categories = get_categories()
    all_data = defaultdict(list)
    total = 0
    
    csv_files = sorted(YEAR_FOLDER.glob('*.csv'))
    print(f"Processing {len(csv_files)} files...")
    
    for i, csv_file in enumerate(csv_files, 1):
        print(f"[{i}/{len(csv_files)}] {csv_file.name}")
        
        lines = normalize_csv(csv_file, ACCOUNT_NAME, categories)
        total += len(lines)
        
        for line in lines:
            year_month = line[:7]  # YYYY-MM
            all_data[year_month].append(line)
        
        print(f"  {len(lines)} transactions (total: {total})")
    
    # Write output files
    header = "Date,Account,Category,Description,Amount"
    for year_month in sorted(all_data.keys()):
        out_file = ACCOUNT_ROOT / f"{year_month}.csv"
        with open(out_file, 'w', encoding='utf-8', newline='') as f:
            f.write(header + '\n')
            f.write('\n'.join(all_data[year_month]))
        print(f"Created: {year_month}.csv ({len(all_data[year_month])} transactions)")
    
    print(f"\nDone! {total} total transactions normalized.")

if __name__ == '__main__':
    main()
