"""
Test PyTorch Scaled Dot Product Attention (SDPA) backends
Verifies GPU compatibility and available attention mechanisms
"""

import torch
import torch.nn.functional as F
from torch.nn.attention import SDPBackend, sdpa_kernel


def test_sdpa():
    print("=" * 60)
    print("PyTorch SDPA Configuration")
    print("=" * 60)
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")

    if torch.cuda.is_available():
        print(f"CUDA version: {torch.version.cuda}")
        print(f"GPU: {torch.cuda.get_device_name(0)}")
        print(
            f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB"
        )
        device = "cuda"
    else:
        print("WARNING: CUDA not available, using CPU")
        device = "cpu"

    print("\n" + "=" * 60)
    print("Testing SDPA Backends")
    print("=" * 60)

    # Test parameters
    batch_size = 2
    seq_len = 512
    num_heads = 8
    head_dim = 64

    # Create sample tensors
    dtype = torch.float16 if device == "cuda" else torch.float32
    q = torch.randn(
        batch_size, num_heads, seq_len, head_dim, device=device, dtype=dtype
    )
    k = torch.randn(
        batch_size, num_heads, seq_len, head_dim, device=device, dtype=dtype
    )
    v = torch.randn(
        batch_size, num_heads, seq_len, head_dim, device=device, dtype=dtype
    )

    print(f"\nInput shapes:")
    print(f"  Query: {q.shape}")
    print(f"  Key: {k.shape}")
    print(f"  Value: {v.shape}")
    print(f"  Device: {device}")
    print(f"  Dtype: {dtype}")

    # Test default SDPA
    print("\n" + "-" * 60)
    print("Running SDPA (automatic backend selection)...")
    print("-" * 60)

    try:
        output = F.scaled_dot_product_attention(q, k, v)
        print(f"[SUCCESS] Output shape: {output.shape}")
        print(f"[SUCCESS] SDPA is working correctly on {device.upper()}")
    except Exception as e:
        print(f"[ERROR] SDPA failed: {e}")
        return

    # Test individual backends
    print("\n" + "=" * 60)
    print("Available SDPA Backends")
    print("=" * 60)

    backends = {
        "FLASH_ATTENTION": SDPBackend.FLASH_ATTENTION,
        "EFFICIENT_ATTENTION": SDPBackend.EFFICIENT_ATTENTION,
        "MATH": SDPBackend.MATH,
    }

    for backend_name, backend in backends.items():
        try:
            with sdpa_kernel([backend]):
                output = F.scaled_dot_product_attention(q, k, v)
            print(f"[OK] {backend_name}")
        except Exception as e:
            print(f"[FAIL] {backend_name}: {str(e)[:60]}")

    print("\n" + "=" * 60)
    print("Usage Example")
    print("=" * 60)
    print("""
# In your code, use SDPA instead of flash_attn:

import torch.nn.functional as F

# Basic usage
output = F.scaled_dot_product_attention(query, key, value)

# With causal masking (for autoregressive models)
output = F.scaled_dot_product_attention(
    query, key, value, 
    is_causal=True
)

# With custom attention mask
output = F.scaled_dot_product_attention(
    query, key, value,
    attn_mask=custom_mask
)
""")

    print("=" * 60)


if __name__ == "__main__":
    test_sdpa()
