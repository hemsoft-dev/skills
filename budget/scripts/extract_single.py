#!/usr/bin/env python3
"""Extract transactions from a single USAA PDF to CSV."""
import re
import sys
import pdfplumber
from pathlib import Path
from datetime import datetime


def extract_transactions(pdf_path):
    transactions = []
    with pdfplumber.open(pdf_path) as pdf:
        text = '\n'.join(page.extract_text() or '' for page in pdf.pages)

    period_match = re.search(r'Statement Period:\s*(\d{2}/\d{2}/\d{4})\s*to\s*(\d{2}/\d{2}/\d{4})', text)
    if period_match:
        end_date = datetime.strptime(period_match.group(2), '%m/%d/%Y')
        year = end_date.year
    else:
        year = 2026
        end_date = datetime(year, 12, 31)

    lines = text.split('\n')
    twoline_pattern = r'^(\d{2}/\d{2})\s+RECURRING DEB CARD PURCH\s+\d+\s+\d+\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'
    twoline_credit_pattern = r'^(\d{2}/\d{2})\s+RECURRING DEB CARD PURCH\s+\d+\s+\d+\s+(?:0|\$0)\s+\$?([\d,]+\.\d{2})\s+\$([\d,]+\.\d{2})$'
    ach_withdrawal_pattern = r'^(\d{2}/\d{2})\s+ACH WITHDRAWAL\s+\d+\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'
    pattern = r'^(\d{2}/\d{2})\s+(.+?)\s+\$?([\d,]+\.\d{2})\s+(?:0|\$0)\s+\$([\d,]+\.\d{2})$'
    credit_pattern = r'^(\d{2}/\d{2})\s+(.+?)\s+(?:0|\$0)\s+\$?([\d,]+\.\d{2})\s+\$([\d,]+\.\d{2})$'

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if 'Beginning Balance' in line or 'Ending Balance' in line:
            i += 1
            continue

        match = re.match(ach_withdrawal_pattern, line)
        if match:
            date_str, amount, balance = match.groups()
            month, day = map(int, date_str.split('/'))
            txn_year = year if month <= end_date.month else year - 1
            full_date = f"{txn_year}-{month:02d}-{day:02d}"
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
                transactions.append((full_date, desc.strip(), -float(amount.replace(',', ''))))
                i += 1
                continue

        match = re.match(twoline_pattern, line)
        if match and i > 0:
            prev_line = lines[i - 1].strip()
            if prev_line and not re.match(r'^\d{2}/\d{2}', prev_line) and 'Balance' not in prev_line:
                date_str, amount, balance = match.groups()
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                transactions.append((full_date, prev_line, -float(amount.replace(',', ''))))
                i += 1
                continue

        match = re.match(twoline_credit_pattern, line)
        if match and i > 0:
            prev_line = lines[i - 1].strip()
            if prev_line and not re.match(r'^\d{2}/\d{2}', prev_line) and 'Balance' not in prev_line:
                date_str, amount, balance = match.groups()
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                transactions.append((full_date, prev_line, float(amount.replace(',', ''))))
                i += 1
                continue

        match = re.match(pattern, line)
        if match:
            date_str, desc, amount, balance = match.groups()
            if 'RECURRING DEB CARD PURCH' not in desc:
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                transactions.append((full_date, desc.strip(), -float(amount.replace(',', ''))))
            i += 1
            continue

        match = re.match(credit_pattern, line)
        if match:
            date_str, desc, amount, balance = match.groups()
            if 'RECURRING DEB CARD PURCH' not in desc:
                month, day = map(int, date_str.split('/'))
                txn_year = year if month <= end_date.month else year - 1
                full_date = f"{txn_year}-{month:02d}-{day:02d}"
                transactions.append((full_date, desc.strip(), float(amount.replace(',', ''))))
            i += 1
            continue

        i += 1
    return transactions


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_single.py <path_to_pdf>")
        sys.exit(1)

    pdf_path = Path(sys.argv[1])
    if not pdf_path.exists():
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)

    print(f"Processing: {pdf_path.name}")
    txns = extract_transactions(pdf_path)
    print(f"Found {len(txns)} transactions")

    csv_path = pdf_path.with_suffix('.csv')
    with open(csv_path, 'w', encoding='utf-8') as f:
        f.write("Date,Description,Amount\n")
        for date, desc, amount in sorted(txns):
            if ',' in desc:
                desc = '"' + desc.replace('"', '""') + '"'
            f.write(f"{date},{desc},{amount:.2f}\n")

    print(f"Wrote: {csv_path}")
    print()
    print("Transactions preview:")
    for t in sorted(txns)[:15]:
        print(f"  {t[0]}  {t[1][:55]:<55}  {t[2]:>10.2f}")


if __name__ == '__main__':
    main()
