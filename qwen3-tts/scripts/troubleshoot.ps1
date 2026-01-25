# Qwen3-TTS Troubleshooting Script
# Diagnoses common issues with PyTorch, CUDA, and qwen-tts setup

Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Qwen3-TTS Troubleshooting" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

# Check Python
Write-Host "`n[1/7] Checking Python..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
Write-Host "  $pythonVersion" -ForegroundColor White

if ($pythonVersion -match "3\.(1[0-4])") {
    Write-Host "  [OK] Python version is compatible" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Python 3.10-3.14 recommended" -ForegroundColor Red
}

# Check PyTorch
Write-Host "`n[2/7] Checking PyTorch..." -ForegroundColor Yellow
$torchCheck = python -c "import torch; print(torch.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  PyTorch: $torchCheck" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] PyTorch not installed" -ForegroundColor Red
    Write-Host "  Install: pip install torch --index-url https://download.pytorch.org/whl/cu128" -ForegroundColor Yellow
}

# Check CUDA availability
Write-Host "`n[3/7] Checking CUDA..." -ForegroundColor Yellow
$cudaCheck = python -c "import torch; print('Available' if torch.cuda.is_available() else 'Not Available')" 2>&1
if ($cudaCheck -match "Available") {
    Write-Host "  CUDA: Available" -ForegroundColor Green
    
    # Get CUDA version
    $cudaVersion = python -c "import torch; print(torch.version.cuda)" 2>&1
    Write-Host "  CUDA Version: $cudaVersion" -ForegroundColor White
    
    # Get GPU name
    $gpuName = python -c "import torch; print(torch.cuda.get_device_name(0))" 2>&1
    Write-Host "  GPU: $gpuName" -ForegroundColor White
    
    # Check for RTX 5090 specific issues
    if ($gpuName -match "RTX 5090") {
        Write-Host "`n  [RTX 5090 Detected]" -ForegroundColor Cyan
        if ($cudaVersion -lt "12.8") {
            Write-Host "  [WARNING] RTX 5090 requires CUDA 12.8+" -ForegroundColor Red
            Write-Host "  Current: CUDA $cudaVersion" -ForegroundColor Red
            Write-Host "  Fix: pip install torch --index-url https://download.pytorch.org/whl/cu128" -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] CUDA version compatible with RTX 5090" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  CUDA: Not Available" -ForegroundColor Red
    Write-Host "  Running in CPU mode (slower)" -ForegroundColor Yellow
}

# Check NVIDIA driver
Write-Host "`n[4/7] Checking NVIDIA Driver..." -ForegroundColor Yellow
try {
    $nvidiaDriver = nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1
    Write-Host "  Driver Version: $nvidiaDriver" -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] nvidia-smi not found" -ForegroundColor Red
    Write-Host "  Install NVIDIA drivers from: https://www.nvidia.com/drivers" -ForegroundColor Yellow
}

# Check qwen-tts
Write-Host "`n[5/7] Checking qwen-tts..." -ForegroundColor Yellow
$qwenCheck = python -c "import qwen_tts; print('Installed')" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  qwen-tts: Installed" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] qwen-tts not installed" -ForegroundColor Red
    Write-Host "  Install: pip install qwen-tts" -ForegroundColor Yellow
}

# Test SDPA
Write-Host "`n[6/7] Testing PyTorch SDPA..." -ForegroundColor Yellow
$sdpaTest = python -c @"
import torch
import torch.nn.functional as F
try:
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    q = torch.randn(2, 8, 64, 32, device=device, dtype=torch.float16 if device == 'cuda' else torch.float32)
    k = torch.randn(2, 8, 64, 32, device=device, dtype=torch.float16 if device == 'cuda' else torch.float32)
    v = torch.randn(2, 8, 64, 32, device=device, dtype=torch.float16 if device == 'cuda' else torch.float32)
    output = F.scaled_dot_product_attention(q, k, v)
    print('Working')
except Exception as e:
    print(f'Failed: {e}')
"@ 2>&1

if ($sdpaTest -match "Working") {
    Write-Host "  SDPA: Working" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] SDPA test failed" -ForegroundColor Red
    Write-Host "  $sdpaTest" -ForegroundColor Red
}

# Check Windows Long Path support
Write-Host "`n[7/7] Checking Windows Long Path Support..." -ForegroundColor Yellow
try {
    $longPathEnabled = Get-ItemProperty -Path "REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -ErrorAction Stop
    if ($longPathEnabled.LongPathsEnabled -eq 1) {
        Write-Host "  Long Path: Enabled" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Long Path not enabled" -ForegroundColor Red
        Write-Host "  Enable with (as Admin):" -ForegroundColor Yellow
        Write-Host "  New-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WARNING] Could not check Long Path setting" -ForegroundColor Red
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Troubleshooting Complete" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nFor detailed testing, run:" -ForegroundColor White
Write-Host "  python scripts/test_sdpa.py" -ForegroundColor Yellow
