# Qwen3-TTS Quick Start

Get up and running with qwen3-tts in 5 minutes.

## Prerequisites

- Windows 10/11
- NVIDIA GPU with CUDA support
- Python 3.10-3.14

## Option 1: Automated Setup (Recommended)

```powershell
# Run the automated setup script
cd C:\Users\User\.claude\skills\qwen3-tts
.\scripts\setup_environment.ps1

# Activate the environment
conda activate qwen3-tts

# Test SDPA
python scripts/test_sdpa.py
```

## Option 2: Manual Setup

### Step 1: Create Environment

```bash
conda create -n qwen3-tts python=3.12 -y
conda activate qwen3-tts
```

### Step 2: Install PyTorch

**For RTX 5090:**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**For RTX 4090:**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

**For RTX 3090 and older:**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### Step 3: Install qwen-tts

```bash
pip install qwen-tts
```

### Step 4: Verify Installation

```bash
python scripts/test_sdpa.py
```

## Troubleshooting

If you encounter issues:

```powershell
.\scripts\troubleshoot.ps1
```

Common fixes:

**GPU not detected:**

```bash
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**Long path errors (run as Administrator):**

```powershell
New-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
```

## Using PyTorch SDPA

Instead of flash-attn, use PyTorch's built-in SDPA:

```python
import torch
import torch.nn.functional as F

# Your attention tensors
query = torch.randn(batch, heads, seq_len, head_dim, device='cuda', dtype=torch.float16)
key = torch.randn(batch, heads, seq_len, head_dim, device='cuda', dtype=torch.float16)
value = torch.randn(batch, heads, seq_len, head_dim, device='cuda', dtype=torch.float16)

# Use SDPA (automatically selects best backend)
output = F.scaled_dot_product_attention(query, key, value)

# For autoregressive models, use causal masking
output = F.scaled_dot_product_attention(query, key, value, is_causal=True)
```

## Expected Warnings (Safe to Ignore)

```
Warning: flash-attn is not installed. Will only run the manual PyTorch version.
```

→ Expected. We're using PyTorch SDPA instead.

```
SoX could not be found!
```

→ Optional dependency. qwen-tts works without it.

## Next Steps

- Read [SKILL.md](SKILL.md) for detailed documentation
- Check [REFERENCE.md](REFERENCE.md) for complete troubleshooting guide
- Review [scripts/README.md](scripts/README.md) for script documentation

## Support

For issues specific to:

- **PyTorch/CUDA:** <https://pytorch.org/get-started/locally/>
- **qwen-tts:** <https://github.com/Qwen/Qwen3-TTS>
- **This skill:** Review REFERENCE.md and run troubleshoot.ps1
