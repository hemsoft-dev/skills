# Qwen3-TTS Setup Guide - Complete Reference

This document captures everything learned during the RTX 5090 + qwen3-tts setup process.

## The Journey: From flash-attn to PyTorch SDPA

### Initial Problem

- User needed to install qwen-tts which depends on flash-attn
- Command: `pip install -U flash-attn --no-build-isolation`
- Initial error: Windows Long Path limitation (260 char limit)

### Challenges Encountered

#### 1. Windows Long Path Support

**Issue:** File paths exceeded 260 characters during installation

**Solution:**

```powershell
# Run as Administrator
New-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
```

**Verification:**

```powershell
Get-ItemProperty -Path "REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled
```

#### 2. CUDA Toolkit Missing

**Issue:** `nvcc was not found` - CUDA compiler not installed

**Solution:** Downloaded and installed CUDA Toolkit 12.4

```bash
# Download from: https://developer.nvidia.com/cuda-downloads
# Silent install with essential components:
cuda_installer.exe -s nvcc_12.4 cudart_12.4 cublas_dev_12.4 cusparse_dev_12.4 visual_studio_integration_12.4
```

**Environment Variables:**

```powershell
setx CUDA_HOME "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
setx PATH "%PATH%;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin"
```

#### 3. PyTorch CPU-only Version

**Issue:** PyTorch 2.10.0+cpu installed, but GPU needed

**Solution:** Uninstall and reinstall with CUDA support

```bash
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

#### 4. RTX 5090 Compatibility

**Issue:** RTX 5090 has compute capability sm_120 (Blackwell architecture)

- PyTorch 2.6 supports up to sm_90
- PyTorch 2.7 nightly supports up to sm_90
- Error: "no kernel image is available for execution on the device"

**Solution:** Upgraded to PyTorch 2.10.0 with CUDA 12.8

```bash
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**Result:** ✓ RTX 5090 fully working with PyTorch 2.10.0+cu128

#### 5. Visual Studio Build Tools

**Issue:** `Microsoft Visual C++ 14.0 or greater is required`

**Attempted Solutions:**

- Manual installer with C++ workload
- winget installation
- Both failed or partially installed

**Final Decision:** Use PyTorch SDPA instead of flash-attn to avoid compilation

### The Solution: PyTorch SDPA

Instead of fighting with flash-attn compilation on Windows, we used PyTorch's built-in Scaled Dot Product Attention (SDPA).

**Advantages:**

- No compilation required
- Built into PyTorch 2.0+
- Automatically selects fastest backend
- Works on all CUDA GPUs
- Similar performance to flash-attn

**Available Backends on RTX 5090:**

- ✓ EFFICIENT_ATTENTION (memory-efficient, optimized)
- ✓ MATH (fallback, always available)
- ✗ FLASH_ATTENTION (not available - PyTorch not compiled with it)

**Usage:**

```python
import torch.nn.functional as F

output = F.scaled_dot_product_attention(
    query,  # [batch, heads, seq_len, head_dim]
    key,
    value,
    is_causal=True  # optional
)
```

## Final Working Configuration

### System

- OS: Windows 11
- GPU: NVIDIA GeForce RTX 5090 (34GB, sm_120)
- CUDA Driver: 13.1 (from nvidia-smi)

### Environment

- Conda env: qwen3-tts
- Python: 3.12.12
- PyTorch: 2.10.0+cu128
- CUDA Toolkit: 12.4 (for development, not required for PyTorch)
- qwen-tts: 0.0.5

### Installation Commands

```bash
# 1. Create environment
conda create -n qwen3-tts python=3.12 -y
conda activate qwen3-tts

# 2. Install PyTorch with CUDA 12.8 (RTX 5090)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 3. Install qwen-tts
pip install qwen-tts

# 4. Verify
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0)}')"
```

### Verification

```python
import torch
import torch.nn.functional as F

# Test SDPA on GPU
device = "cuda"
q = torch.randn(2, 8, 512, 64, device=device, dtype=torch.float16)
k = torch.randn(2, 8, 512, 64, device=device, dtype=torch.float16)
v = torch.randn(2, 8, 512, 64, device=device, dtype=torch.float16)

output = F.scaled_dot_product_attention(q, k, v)
print(f"Success! Output: {output.shape}, Device: {output.device}")
```

## Key Learnings

### 1. GPU Compute Capability Matters

Newer GPUs need newer PyTorch builds:

- RTX 5090 (sm_120) → PyTorch 2.10.0+cu128
- RTX 4090 (sm_89) → PyTorch 2.6+cu124
- RTX 3090 (sm_86) → PyTorch 2.0+cu118

Check with: `nvidia-smi --query-gpu=compute_cap --format=csv`

### 2. CUDA Driver vs CUDA Toolkit

- **CUDA Driver** (from nvidia-smi): Installed with GPU drivers
- **CUDA Toolkit** (nvcc): Needed for compiling CUDA code
- PyTorch includes CUDA runtime, doesn't need Toolkit for inference

### 3. PyTorch Index URLs

Different CUDA versions have different wheels:

```
cu128 → CUDA 12.8 (newest GPUs)
cu126 → CUDA 12.6
cu124 → CUDA 12.4
cu118 → CUDA 11.8 (most compatible)
cpu → CPU-only (no GPU)
```

### 4. flash-attn on Windows is Hard

Requirements for flash-attn compilation:

- CUDA Toolkit (nvcc)
- Visual Studio Build Tools with C++ compiler
- Windows Long Path support
- Compatible GPU architecture
- Significant build time

**Better alternative:** Use PyTorch SDPA

### 5. Warning Messages to Ignore

```
Warning: flash-attn is not installed. Will only run the manual PyTorch version.
```

→ Safe to ignore, SDPA provides the functionality

```
SoX could not be found!
```

→ Optional dependency, qwen-tts works without it

```
NVIDIA GeForce RTX 5090 with CUDA capability sm_120 is not compatible...
```

→ Only appears with older PyTorch, fixed by upgrading to 2.10.0+cu128

## GPU Compatibility Matrix

| GPU | Architecture | Compute Cap | Min PyTorch | CUDA Version | Index URL |
|-----|-------------|-------------|-------------|--------------|-----------|
| RTX 5090 | Blackwell | sm_120 | 2.10.0 | 12.8 | cu128 |
| RTX 4090 | Ada Lovelace | sm_89 | 2.0 | 12.4 | cu124 |
| RTX 4080 | Ada Lovelace | sm_89 | 2.0 | 12.4 | cu124 |
| RTX 3090 | Ampere | sm_86 | 1.7 | 11.8 | cu118 |
| RTX 3080 | Ampere | sm_86 | 1.7 | 11.8 | cu118 |
| RTX 2080 Ti | Turing | sm_75 | 1.0 | 11.8 | cu118 |

## Troubleshooting Common Errors

### Error: "no kernel image is available for execution"

**Cause:** GPU architecture newer than PyTorch supports
**Fix:** Install PyTorch with newer CUDA version (see matrix above)

### Error: "CUDA_HOME environment variable is not set"

**Cause:** Trying to compile CUDA code without CUDA Toolkit
**Fix:** Either install CUDA Toolkit or use pre-built packages

### Error: "Microsoft Visual C++ 14.0 or greater is required"

**Cause:** Trying to compile C++ extensions without compiler
**Fix:** Install VS Build Tools or use packages that don't need compilation

### Error: "Long path not supported"

**Cause:** Windows 260-character path limit
**Fix:** Enable Long Path support (see above)

### Warning: "Torch was not compiled with flash attention"

**Status:** Expected, not an error
**Action:** Use SDPA instead (it's already working)

## Files Created

```
.claude/skills/qwen3-tts/
├── SKILL.md                           # Main skill documentation
├── scripts/
│   ├── README.md                      # Scripts documentation
│   ├── test_sdpa.py                   # Test SDPA backends
│   ├── setup_environment.ps1          # Automated setup
│   ├── troubleshoot.ps1               # Diagnostic tool
│   └── run_inference.py               # Inference template
├── History/
│   └── 2026-01-23.md                  # This session
└── REFERENCE.md                       # This file
```

## Resources

- **Qwen3-TTS:** <https://github.com/Qwen/Qwen3-TTS>
- **PyTorch Install:** <https://pytorch.org/get-started/locally/>
- **SDPA Docs:** <https://pytorch.org/docs/stable/generated/torch.nn.functional.scaled_dot_product_attention.html>
- **CUDA Toolkit:** <https://developer.nvidia.com/cuda-downloads>
- **VS Build Tools:** <https://visualstudio.microsoft.com/visual-cpp-build-tools/>

## Timeline

1. Initial attempt: flash-attn installation
2. Fixed: Windows Long Path support
3. Installed: CUDA Toolkit 12.4
4. Upgraded: PyTorch CPU → PyTorch+CUDA 12.4
5. Problem: RTX 5090 not supported (sm_120)
6. Tried: PyTorch 2.7 nightly (still no sm_120)
7. Tried: PyTorch with CUDA 12.6 (still no sm_120)
8. **Solution:** PyTorch 2.10.0+cu128 ✓
9. **Alternative:** Use SDPA instead of flash-attn ✓
10. Result: Fully functional setup

**Total time:** ~2 hours of troubleshooting
**Key insight:** Don't fight with flash-attn on Windows, use PyTorch SDPA
