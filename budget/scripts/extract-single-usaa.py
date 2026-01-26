#!/usr/bin/env python3
"""Extract transactions from a single USAA PDF file."""
import sys
import re
import csv
import pdfplumber
from pathlib import Path
from datetime import datetime

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
        # Try to infer year from filename
        year_match = re.search(r'(\d{4})', Path(pdf_path).name)
        year = int(year_match.group(1)) if year_match else 2026
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

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python extract-single-usaa.py <pdf_path>")
        sys.exit(1)
    
    pdf_path = Path(sys.argv[1])
    if not pdf_path.exists():
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)
    
    print(f"Extracting from: {pdf_path.name}")
    txns = extract_transactions(str(pdf_path))
    print(f"Found {len(txns)} transactions")
    
    # Write CSV next to PDF
    csv_path = pdf_path.with_suffix('.csv')
    with open(csv_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Date', 'Description', 'Amount'])
        for date, desc, amount in sorted(txns):
            writer.writerow([date, desc, f"{amount:.2f}"])
    
    print(f"Wrote: {csv_path}")
