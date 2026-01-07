# pdf-to-csv.py
# Extracts transaction data from Chase Credit Card PDF statements to CSV

import pdfplumber
import re
import csv
import sys
from pathlib import Path

def extract_transactions(pdf_path):
    """Extract transactions from a Chase Credit Card PDF statement."""
    transactions = []
    
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if not text:
                continue
            
            lines = text.split('\n')
            for line in lines:
                # Match: MM/DD Description Amount (amount at end of line)
                match = re.match(r'^(\d{2}/\d{2})\s+(.+?)\s+(-?[\d,]+\.\d{2})$', line.strip())
                if match:
                    date = match.group(1)
                    desc = match.group(2).strip()
                    amount = match.group(3).replace(',', '')
                    transactions.append((date, desc, amount))
    
    return transactions

def pdf_to_csv(pdf_path, csv_path):
    """Convert a PDF statement to CSV."""
    txns = extract_transactions(pdf_path)
    
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['Date', 'Description', 'Amount'])
        for txn in txns:
            writer.writerow(txn)
    
    return len(txns)

def process_folder(folder_path):
    """Process all PDFs in a folder."""
    folder = Path(folder_path)
    total = 0
    
    for pdf_file in sorted(folder.glob('*.pdf')):
        csv_file = pdf_file.with_suffix('.csv')
        count = pdf_to_csv(str(pdf_file), str(csv_file))
        total += count
        print(f'{pdf_file.name} -> {csv_file.name}: {count} transactions')
    
    print(f'\nTotal: {total} transactions')
    return total

if __name__ == '__main__':
    if len(sys.argv) > 1:
        process_folder(sys.argv[1])
    else:
        # Default: Chase Credit Card 2025
        process_folder(r'F:\OneDrive\Documents\Budget\Statements\Chase Credit Card\2025')
