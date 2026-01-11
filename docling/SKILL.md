---
name: docling
description: V1.0 - Expert in Docling document parsing, conversion, and processing for PDF, DOCX, PPTX, XLSX, HTML, images, and audio files with gen AI integration.
license: MIT
dependencies: python>=3.12, docling==2.67.0, click<8.2
compatibility: Windows, macOS, Linux. Requires Python 3.12+. Click must be <8.2 for CLI compatibility.
---

# Docling

Expert guidance for using Docling - an open-source document parsing and conversion toolkit by IBM Research, perfect for preparing documents for gen AI applications.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Installation

```powershell
pip install docling
```

**CLI Compatibility Fix**: If `docling --help` fails with "Secondary flag is not valid for non-boolean flag", downgrade click:

```powershell
pip install 'click<8.2'
```

## Core Features

### Supported Input Formats

- **Documents**: PDF, DOCX, PPTX, XLSX, HTML, Markdown
- **Images**: PNG, TIFF, JPEG
- **Audio**: WAV, MP3 (with ASR)
- **Web**: WebVTT (captions)
- **Specialized**: METS (books), USPTO XML, JSON

### Supported Output Formats

- **Markdown** - Default, best for most use cases
- **JSON** - Structured, lossless representation
- **YAML** - Compact, human-readable
- **HTML** - Web-friendly with metadata
- **DocTags** - Custom markup format
- **Text** - Plain text extraction

### Advanced Capabilities

- **PDF Understanding**: Layout analysis, reading order, table structure detection
- **OCR Support**: EasyOCR, RapidOCR, Tesseract for scanned documents
- **Visual Language Models**: GraniteDocling, SmolDocling, GOT-OCR 2
- **Audio Processing**: Whisper ASR models for speech-to-text
- **Code & Formula Detection**: Automatic enrichment for code blocks and LaTeX
- **Image Classification**: Diagram, chart, photo detection
- **Local Execution**: No cloud dependencies, air-gapped friendly

## Basic Usage

### Python API

```python
from docling.document_converter import DocumentConverter

# Convert a document
converter = DocumentConverter()
result = converter.convert("document.pdf")

# Export to Markdown
markdown = result.document.export_to_markdown()
print(markdown)

# Export to JSON
json_str = result.document.export_to_json()

# Export to DocTags
doctags = result.document.export_to_doctags()
```

### CLI

```bash
# Basic conversion to Markdown
docling document.pdf

# Convert multiple files
docling *.pdf

# Specify output format
docling document.pdf --to json --output ./output

# Convert from URL
docling https://arxiv.org/pdf/2408.09869

# Use VLM pipeline for better quality
docling document.pdf --pipeline vlm --vlm-model granite_docling

# Force OCR on all content
docling scanned.pdf --force-ocr

# Process with custom settings
docling document.pdf --no-tables --no-ocr --output ./results
```

### Pipeline Options

| Pipeline | Best For | Speed | Cost |
|----------|----------|-------|------|
| `standard` | Most documents | ⚡⚡⚡ | Free |
| `vlm` | Complex layouts, accuracy | ⚡ | Needs model download |
| `legacy` | Compatibility | ⚡⚡ | Free |
| `asr` | Audio/video files | ⚡⚡ | Free |

## Integration with AI/ML Frameworks

### LangChain

```python
from langchain.document_loaders import DoclingLoader

loader = DoclingLoader(file_path="document.pdf")
docs = loader.load()
```

### LlamaIndex

```python
from llama_index.readers.docling import DoclingReader

reader = DoclingReader()
docs = reader.load_data("document.pdf")
```

### Haystack

```python
from haystack_integrations.document_loaders.docling import DoclingLoader

loader = DoclingLoader()
docs = loader.run(file_paths=["document.pdf"])
```

## Common Workflows

### 1. Bulk Document Processing

```python
from docling.document_converter import DocumentConverter
from pathlib import Path

converter = DocumentConverter()
output_dir = Path("output")
output_dir.mkdir(exist_ok=True)

for pdf_file in Path(".").glob("*.pdf"):
    result = converter.convert(str(pdf_file))
    output_file = output_dir / f"{pdf_file.stem}.md"
    output_file.write_text(result.document.export_to_markdown())
```

### 2. Extract Tables to CSV

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("document.pdf")

# Tables are in result.document.tables
for i, table in enumerate(result.document.tables):
    csv = table.export_to_csv()
    print(f"Table {i}:\n{csv}")
```

### 3. RAG Pipeline Preparation

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HierarchicalChunker

converter = DocumentConverter()
result = converter.convert("document.pdf")

# Use hierarchical chunking for RAG
chunker = HierarchicalChunker()
chunks = chunker.chunk(result.document)

for chunk in chunks:
    print(chunk.text[:100] + "...")
```

### 4. Image Extraction

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter(image_export_mode="referenced")
result = converter.convert("document.pdf")

# Images are exported to disk and referenced in output
markdown = result.document.export_to_markdown()
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `docling --help` fails | Downgrade click: `pip install 'click<8.2'` |
| Out of memory on large PDFs | Use `--page-batch-size 2` to process fewer pages at once |
| OCR not detecting text | Try `--force-ocr` to replace all text with OCR results |
| Slow processing | Use `--no-tables --no-ocr` to skip enrichment, or switch to `standard` pipeline |
| Model download issues | Set `--artifacts-path /custom/path` if network-restricted |

## Performance Tuning

```bash
# Fast mode (no enrichment)
docling document.pdf --no-tables --no-ocr

# Multi-threaded processing
docling *.pdf --num-threads 8

# Smaller batches for memory-constrained systems
docling document.pdf --page-batch-size 2

# GPU acceleration (if CUDA available)
docling document.pdf --device cuda
```

## Version Information

- **Current Version**: 2.67.0
- **Python**: 3.12+
- **Key Dependencies**: click<8.2, typer, pydantic, torch, transformers
- **License**: MIT

## Resources

- **Repository**: <https://github.com/docling-project/docling>
- **Documentation**: <https://docling-project.github.io/docling/>
- **Technical Report**: <https://arxiv.org/abs/2408.09869>
- **Discussions**: <https://github.com/docling-project/docling/discussions>
