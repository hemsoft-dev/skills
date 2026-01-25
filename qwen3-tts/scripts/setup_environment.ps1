# Qwen3-TTS Environment Setup Script
# Automates PyTorch and qwen-tts installation with optimal settings

param(
    [string]$GPU = "auto",  # auto, rtx5090, rtx4090, rtx3090, cpu
    [switch]$SkipConda
)

Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Qwen3-TTS Environment Setup" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

# Detect GPU if auto
if ($GPU -eq "auto") {
    Write-Host "`nDetecting GPU..." -ForegroundColor Yellow
    try {
        $gpuInfo = nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
        if ($gpuInfo -match "RTX 5090") {
            $GPU = "rtx5090"
            Write-Host "Detected: RTX 5090 (Blackwell)" -ForegroundColor Green
        } elseif ($gpuInfo -match "RTX 4090") {
            $GPU = "rtx4090"
            Write-Host "Detected: RTX 4090 (Ada Lovelace)" -ForegroundColor Green
        } elseif ($gpuInfo -match "RTX 3090") {
            $GPU = "rtx3090"
            Write-Host "Detected: RTX 3090 (Ampere)" -ForegroundColor Green
        } else {
            $GPU = "rtx3090"  # Default to widely compatible version
            Write-Host "Detected: $gpuInfo" -ForegroundColor Yellow
            Write-Host "Using default CUDA 11.8 (compatible with most GPUs)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "No NVIDIA GPU detected, using CPU mode" -ForegroundColor Red
        $GPU = "cpu"
    }
}

# Select PyTorch index URL based on GPU
$cudaVersions = @{
    "rtx5090" = "cu128"
    "rtx4090" = "cu124"
    "rtx3090" = "cu118"
    "cpu" = "cpu"
}

$cudaVersion = $cudaVersions[$GPU]
$indexUrl = "https://download.pytorch.org/whl/$cudaVersion"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  GPU Profile: $GPU" -ForegroundColor White
Write-Host "  CUDA Version: $cudaVersion" -ForegroundColor White
Write-Host "  PyTorch Index: $indexUrl" -ForegroundColor White

# Create conda environment
if (-not $SkipConda) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Creating Conda Environment" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    $envExists = conda env list | Select-String "qwen3-tts"
    if ($envExists) {
        Write-Host "Environment 'qwen3-tts' already exists" -ForegroundColor Yellow
        $response = Read-Host "Remove and recreate? (y/n)"
        if ($response -eq "y") {
            conda env remove -n qwen3-tts -y
            conda create -n qwen3-tts python=3.12 -y
        }
    } else {
        conda create -n qwen3-tts python=3.12 -y
    }
    
    Write-Host "`nActivate with: conda activate qwen3-tts" -ForegroundColor Green
}

# Install PyTorch
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Installing PyTorch" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "Running: pip install torch torchvision torchaudio --index-url $indexUrl" -ForegroundColor Yellow
pip install torch torchvision torchaudio --index-url $indexUrl

# Install qwen-tts
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Installing Qwen3-TTS" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

pip install qwen-tts

# Verify installation
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Verifying Installation" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

python -c @"
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'CUDA Version: {torch.version.cuda}')
"@

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. conda activate qwen3-tts" -ForegroundColor White
Write-Host "  2. Test SDPA: python scripts/test_sdpa.py" -ForegroundColor White
Write-Host "  3. Run inference: python scripts/run_inference.py" -ForegroundColor White
