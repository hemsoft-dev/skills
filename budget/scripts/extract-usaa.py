#!/usr/bin/env python3
"""
extract-usaa.py
Extracts transactions from USAA PDF statements (Checking/Savings).
Usage: python extract-usaa.py "Account Folder Name"
"""
import re
import sys
import pdfplumber
from pathlib import Path
from datetime import datetime

STATEMENTS_ROOT = Path(r"F:\OneDrive\Documents\Budget\Statements")

def extract_transactions(pdf_path):
    """Extract transactions from a USAA statement PDF."""
    transactions = []
    
    with pdfplumber.open(pdf_path) as pdf:
        text = '\n'.join(page.extract_text() or '' for page in pdf.pages)
    
    # Extract statement period for year context
    period_match = re.search(r'Statement Period:\s*(\d{2}/\d{2}/\d{4})\s*to\s*(\d{2}/\d{2}/\d{4})', text)
    if period_match:
        end_date = datetime.strptime(period_match.group(2), '%m/%d/%Y')
        year = end_date.year
    else:
        year = 2025
        end_date = datetime(year, 12, 31)
    
    lines = text.split('\n')
    
    # Two-line format pattern:
    # Line 1: Merchant description (no date prefix)
    # Line 2: MM/DD RECURRING DEB CARD PURCH MMDDYY ID $amount 0 $balance
    twoline_pattern = r'^(\d{2}/\d{2})\s+RECURRING DEB CARD PURCH\s+\d+\s+\d+\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'
    twoline_credit_pattern = r'^(\d{2}/\d{2})\s+RECURRING DEB CARD PURCH\s+\d+\s+\d+\s+(?:0|\$0)\s+\$?([\d,]+\.\d{2})\s+\$([\d,]+\.\d{2})$'
    
    # ACH withdrawal pattern where description is on a following line
    ach_withdrawal_pattern = r'^(\d{2}/\d{2})\s+ACH WITHDRAWAL\s+\d+\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'

    # Single-line patterns (original)
    pattern = r'^(\d{2}/\d{2})\s+(.+?)\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'
    credit_pattern = r'^(\d{2}/\d{2})\s+(.+?)\s+(?:0|\$0)\s+\$?([\d,]+\.\d{2})\s+\$([\d,]+\.\d{2})$'
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip header/summary lines
        if 'Beginning Balance' in line or 'Ending Balance' in line:
            i += 1
            continue
        
        # Try ACH withdrawal pattern (description on next line)
        match = re.match(ach_withdrawal_pattern, line)
        if match:
            date_str, amount, balance = match.groups()
            month, day = map(int, date_str.split('/'))
            txn_year = year if month <= end_date.month else year - 1
            full_date = f"{txn_year}-{month:02d}-{day:02d}"

            # Look ahead for the merchant line (skip masked account rows like ***********1234)
            desc = None
            lookahead = i + 1
            while lookahead < len(lines):
                la_line = lines[lookahead].strip()
                if not la_line:
                    lookahead += 1
                    continue
                if re.match(r'^\d{2}/\d{2}', la_line):
                    break
                if re.match(r'^\*+\d*$', la_line):
                    lookahead += 1
                    continue
                desc = la_line
                break

            if desc:
                amount_val = -float(amount.replace(',', ''))
                transactions.append((full_date, desc.strip(), amount_val))
                i += 1
                continue

        # Try two-line debit pattern (merchant on previous line)
        match = re.match(twoline_pattern, line)
        if match and i > 0:
            prev_line = lines[i-1].strip()
            # Previous line should be merchant name (no date prefix, not a transaction line)
            if prev_line and not re.match(r'^\d{2}/\d{2}', prev_line) and not 'Balance' in prev_line:
                date_str, amount, balance = match.groups()
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                amount_val = -float(amount.replace(',', ''))
                transactions.append((full_date, prev_line, amount_val))
                i += 1
                continue
        
        # Try two-line credit pattern
        match = re.match(twoline_credit_pattern, line)
        if match and i > 0:
            prev_line = lines[i-1].strip()
            if prev_line and not re.match(r'^\d{2}/\d{2}', prev_line) and not 'Balance' in prev_line:
                date_str, amount, balance = match.groups()
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                amount_val = float(amount.replace(',', ''))
                transactions.append((full_date, prev_line, amount_val))
                i += 1
                continue
            
        # Try single-line debit pattern
        match = re.match(pattern, line)
        if match:
            date_str, desc, amount, balance = match.groups()
            # Skip if this is a RECURRING DEB line (handled by two-line pattern)
            if 'RECURRING DEB CARD PURCH' not in desc:
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                amount_val = -float(amount.replace(',', ''))
                transactions.append((full_date, desc.strip(), amount_val))
            i += 1
            continue
        
        # Try single-line credit pattern
        match = re.match(credit_pattern, line)
        if match:
            date_str, desc, amount, balance = match.groups()
            if 'RECURRING DEB CARD PURCH' not in desc:
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                amount_val = float(amount.replace(',', ''))
                transactions.append((full_date, desc.strip(), amount_val))
            i += 1
            continue
        
        i += 1
    
    return transactions

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract-usaa.py 'Account Folder Name'")
        sys.exit(1)
    
    account_name = sys.argv[1]
    account_path = STATEMENTS_ROOT / account_name / "2025"
    
    if not account_path.exists():
        print(f"Error: Path not found: {account_path}")
        sys.exit(1)
    
    all_transactions = []
    pdf_files = sorted(account_path.glob('*.pdf'))
    
    print(f"[{account_name}] Processing {len(pdf_files)} PDF files...")
    
    for pdf_file in pdf_files:
        print(f"  {pdf_file.name}", end='')
        txns = extract_transactions(pdf_file)
        all_transactions.extend(txns)
        print(f" -> {len(txns)} transactions")
    
    print(f"\nTotal: {len(all_transactions)} transactions")
    
    # Write combined CSV
    output_file = account_path / "all_transactions.csv"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("Date,Description,Amount\n")
        for date, desc, amount in sorted(all_transactions):
            # Escape description if it contains commas
            if ',' in desc:
                desc = f'"{desc}"'
            f.write(f"{date},{desc},{amount:.2f}\n")
    
    print(f"Wrote: {output_file}")

if __name__ == '__main__':
    main()
