---
name: qwen3-tts
description: V1.1 - Expert in Qwen3-TTS text-to-speech model setup, PyTorch SDPA optimization for RTX 5090, and troubleshooting flash-attn alternatives on Windows.
license: Apache-2.0
compatibility: Requires Python 3.10-3.14, PyTorch 2.10.0+cu128, CUDA 12.8+, Windows 10+, NVIDIA GPU with CUDA support
metadata:
  author: OpenCode
  version: "1.1"
  conda_env: qwen3-tts
  pytorch_version: 2.10.0+cu128
dependencies: python>=3.10, torch==2.10.0+cu128, torchaudio, qwen-tts>=0.0.5, accelerate, einops, gradio, librosa, onnxruntime, soundfile, sox, transformers
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the qwen3-tts directory (path contains 'qwen3-tts'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if qwen3-tts was used (check if any files in qwen3-tts directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in qwen3-tts directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Qwen3-TTS

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert knowledge for Qwen3-TTS text-to-speech model setup, PyTorch optimization, and troubleshooting on Windows with NVIDIA GPUs.

## Environment Setup

### Conda Environment

```bash
conda create -n qwen3-tts python=3.12
conda activate qwen3-tts
```

### PyTorch Installation (CRITICAL for RTX 5090 and newer GPUs)

**For RTX 5090 / Blackwell Architecture (sm_120):**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**For RTX 4090 / Ada Lovelace (sm_89):**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

**For older GPUs:**

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

**Verify GPU support:**

```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
```

### Qwen3-TTS Installation

```bash
pip install qwen-tts
```

## Flash Attention Alternative: PyTorch SDPA

**IMPORTANT:** flash-attn is difficult to compile on Windows and requires:

- CUDA Toolkit with nvcc
- Visual Studio Build Tools with C++ compiler
- Long Path support enabled
- Compatible GPU architecture

**Recommended Solution:** Use PyTorch's built-in Scaled Dot Product Attention (SDPA) instead.

### PyTorch SDPA Benefits

- Built into PyTorch 2.0+ (no compilation needed)
- Automatically selects fastest backend (Efficient Attention, Math)
- Works on all CUDA-enabled GPUs
- Similar performance to flash-attn
- Zero setup required

### Using SDPA in Code

```python
import torch.nn.functional as F

# Replace flash_attn_func with SDPA
output = F.scaled_dot_product_attention(
    query,  # shape: [batch, heads, seq_len, head_dim]
    key,    # shape: [batch, heads, seq_len, head_dim]
    value,  # shape: [batch, heads, seq_len, head_dim]
    is_causal=True  # Optional: for autoregressive models
)
```

### Available SDPA Backends

- **EFFICIENT_ATTENTION**: Memory-efficient, optimized for speed
- **MATH**: Fallback implementation, always available
- **FLASH_ATTENTION**: Only if PyTorch compiled with flash-attn (rare on Windows)

### Verify SDPA

Use script: `scripts/test_sdpa.py`

## Windows-Specific Setup

### Enable Long Path Support (Required)

```powershell
# Run as Administrator
New-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
```

### CUDA Toolkit Installation (if needed for other packages)

```bash
# Download CUDA 12.4+
https://developer.nvidia.com/cuda-downloads
```

### Set CUDA_HOME (if needed)

```powershell
setx CUDA_HOME "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
setx PATH "%PATH%;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin"
```

## Troubleshooting

### GPU Not Detected

**Issue:** RTX 5090 shows "no kernel image is available for execution"

**Solution:** Install PyTorch with CUDA 12.8:

```bash
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

### Flash-Attn Compilation Errors

**Common Errors:**

- "nvcc was not found" → Missing CUDA Toolkit
- "Microsoft Visual C++ 14.0 required" → Missing VS Build Tools
- "Long path not supported" → Enable Long Path support
- "CUDA_HOME not set" → Set CUDA_HOME environment variable

**Best Solution:** Don't use flash-attn on Windows. Use PyTorch SDPA instead (see above).

### SoX Not Found Warning

```bash
# This is non-critical, qwen-tts works without SoX
# To install: choco install sox (optional)
```

## Scripts

All helper scripts are in `scripts/` directory:

- `test_sdpa.py` - Test PyTorch SDPA backends and verify GPU
- `setup_environment.ps1` - Automated environment setup
- `run_inference.py` - Example qwen3-tts inference
- `qwen3_tts_voicedesign.py` - VoiceDesign model with consistency parameters (used by `play -hq` command)
- `voice_profiles.ps1` - Voice profile definitions for different voices (loaded by PowerShell profile)

## Known GPU Compatibility

| GPU Architecture | Compute Capability | PyTorch CUDA Version |
|------------------|-------------------|---------------------|
| RTX 5090 (Blackwell) | sm_120 | cu128 (CUDA 12.8+) |
| RTX 4090 (Ada Lovelace) | sm_89 | cu124 (CUDA 12.4+) |
| RTX 3090 (Ampere) | sm_86 | cu118 (CUDA 11.8+) |
| RTX 2080 Ti (Turing) | sm_75 | cu118 (CUDA 11.8+) |

## Voice Consistency Parameters

The `qwen3_tts_voicedesign.py` script uses several parameters to maximize voice consistency:

### Primary Parameters

- **temperature=0.1** - Very low randomness in generation
- **do_sample=False** - Deterministic generation (no sampling)
- **seed=42** - Fixed random seed for reproducibility

### Advanced Consistency Parameters

- **repetition_penalty=1.1** - Reduces token repetition (values > 1.0 penalize repeated tokens)
- **subtalker_dosample=False** - Disables sampling in sub-talker component (qwen3-tts-tokenizer-v2)
- **subtalker_temperature=0.0** - Deterministic sub-talker generation

These parameters work together to minimize voice variation between generations while maintaining ~30 second generation time.

## Key Learnings from Setup

1. **PyTorch version matters** - Newer GPUs need newer CUDA versions
2. **SDPA is the practical choice** - flash-attn is hard to compile on Windows
3. **Long Path support is required** - Many Python packages have long filenames
4. **CUDA Toolkit ≠ CUDA Driver** - Driver (from nvidia-smi) is different from Toolkit
5. **RTX 5090 needs CUDA 12.8+** - Older PyTorch versions don't support sm_120

## References

- Qwen3-TTS GitHub: <https://github.com/Qwen/Qwen3-TTS>
- PyTorch Install: <https://pytorch.org/get-started/locally/>
- SDPA Docs: <https://pytorch.org/docs/stable/generated/torch.nn.functional.scaled_dot_product_attention.html>
