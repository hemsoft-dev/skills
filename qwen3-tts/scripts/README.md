# Qwen3-TTS Scripts

Helper scripts for setting up and testing qwen3-tts with PyTorch SDPA.

## Available Scripts

### `test_sdpa.py`

Tests PyTorch Scaled Dot Product Attention backends and verifies GPU compatibility.

**Usage:**

```bash
python scripts/test_sdpa.py
```

**What it does:**

- Checks PyTorch and CUDA availability
- Tests SDPA on your GPU
- Reports which attention backends are available (Flash, Efficient, Math)
- Shows example usage code

### `setup_environment.ps1`

Automated environment setup for qwen3-tts with GPU-specific PyTorch installation.

**Usage:**

```powershell
# Auto-detect GPU and setup
.\scripts\setup_environment.ps1

# Specify GPU explicitly
.\scripts\setup_environment.ps1 -GPU rtx5090
.\scripts\setup_environment.ps1 -GPU rtx4090
.\scripts\setup_environment.ps1 -GPU cpu

# Skip conda environment creation
.\scripts\setup_environment.ps1 -SkipConda
```

**What it does:**

- Detects your GPU automatically
- Creates conda environment (qwen3-tts)
- Installs correct PyTorch version for your GPU
- Installs qwen-tts and dependencies
- Verifies installation

### `troubleshoot.ps1`

Diagnoses common setup issues and provides fixes.

**Usage:**

```powershell
.\scripts\troubleshoot.ps1
```

**What it checks:**

- Python version compatibility
- PyTorch installation
- CUDA availability
- NVIDIA driver version
- qwen-tts installation
- SDPA functionality
- Windows Long Path support

### `run_inference.py`

Template script for qwen3-tts inference.

**Usage:**

```bash
python scripts/run_inference.py
```

**Note:** This is a template. Update with actual qwen-tts API based on official documentation.

### `qwen3_tts_voicedesign.py`

Production script for generating audio with VoiceDesign model and enhanced consistency parameters.

**Usage:**

```bash
# Activate conda environment first
conda activate qwen3-tts

# Generate with default voice (British female)
python scripts/qwen3_tts_voicedesign.py "Your text here"

# Generate with custom voice description
python scripts/qwen3_tts_voicedesign.py "VOICE:Casual American male, friendly" "Your text here"
```

**Features:**

- Uses VoiceDesign model for natural language voice descriptions
- Enhanced consistency parameters (temperature=0.1, repetition_penalty=1.1, subtalker settings)
- Outputs to TEMP folder by default (keeps User folder clean)
- Integrated with PowerShell `play -hq` command

**Consistency Parameters:**

- `temperature=0.1` - Very low randomness
- `do_sample=False` - Deterministic generation
- `seed=42` - Fixed random seed
- `repetition_penalty=1.1` - Reduces token repetition
- `subtalker_dosample=False` - Deterministic sub-talker
- `subtalker_temperature=0.0` - Zero randomness in sub-talker

### `voice_profiles.ps1`

Voice profile definitions for the PowerShell `play` function.

**Profiles:**

- `british` - Sophisticated mature British female (default)
- `pro` - Professional American female narrator
- `brit-male` - Sophisticated British male
- `casual` - Casual American male

**Usage:**
This file is automatically loaded by your PowerShell profile. Use with:

```powershell
play -hq "Hello world"                    # Default (british)
play -hq -voice pro "Hello"               # Professional narrator
play -hq -voice brit-male "Good day"      # British male
```

### `cleanup_user_folder.ps1`

Cleans up old qwen3-tts files from User folder after reorganization.

**Usage:**

```powershell
.\scripts\cleanup_user_folder.ps1
```

**What it removes:**

- Old scripts (qwen3_voice_profiles.ps1, qwen3_tts_voicedesign.py, qwen3_tts_clone.py)
- Test files (test_voice_consistency.ps1, consistency_test_*.wav)
- Temporary files (qwen3_output.wav, qwen3_reference_voice.wav, qwen3_consistency_notes.md)

## Quick Start

1. **Setup environment:**

   ```powershell
   .\scripts\setup_environment.ps1
   conda activate qwen3-tts
   ```

2. **Test SDPA:**

   ```bash
   python scripts/test_sdpa.py
   ```

3. **Troubleshoot if needed:**

   ```powershell
   .\scripts\troubleshoot.ps1
   ```

## GPU-Specific Notes

### RTX 5090 (Blackwell - sm_120)

- Requires PyTorch with CUDA 12.8+
- Install: `pip install torch --index-url https://download.pytorch.org/whl/cu128`

### RTX 4090 (Ada Lovelace - sm_89)

- Requires PyTorch with CUDA 12.4+
- Install: `pip install torch --index-url https://download.pytorch.org/whl/cu124`

### RTX 3090 and older (Ampere - sm_86)

- Compatible with CUDA 11.8+
- Install: `pip install torch --index-url https://download.pytorch.org/whl/cu118`

## Common Issues

### "no kernel image is available for execution"

Your GPU architecture is newer than your PyTorch build supports.

- **Fix:** Install PyTorch with newer CUDA version (see GPU-specific notes above)

### "flash-attn is not installed"

This is expected and not a problem. We use PyTorch SDPA instead.

- **Status:** Safe to ignore
- **Alternative:** PyTorch's built-in SDPA provides similar performance

### "SoX could not be found"

SoX is optional for qwen-tts.

- **Fix (optional):** `choco install sox`
- **Status:** Non-critical, can ignore

### Long Path errors

Windows has 260-character path limit by default.

- **Fix:** Run troubleshoot.ps1 for instructions to enable Long Path support
