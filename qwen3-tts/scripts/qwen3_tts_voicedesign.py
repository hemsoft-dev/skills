"""
Qwen3-TTS VoiceDesign Audio Generation Script
Generates audio with custom voice descriptions using natural language
"""

import torch
import numpy as np
from qwen_tts import Qwen3TTSModel
import scipy.io.wavfile as wavfile
import os
from typing import Optional


def generate_audio_voicedesign(
    text: str,
    output_path: str = "output.wav",
    voice_description: str = "Professional British female voice, clear and articulate, mid-30s",
    language: str = "english",
    temperature: float = 0.1,
    seed: int = 42,
    repetition_penalty: float = 1.1,
):
    """
    Generate audio from text using Qwen3-TTS VoiceDesign
    
    Args:
        text: The text to convert to speech
        output_path: Where to save the output WAV file
        voice_description: Natural language description of the desired voice
        language: Language code (default: english)
        temperature: Sampling temperature (lower = more consistent, default: 0.1)
        seed: Random seed for reproducibility (default: 42)
        repetition_penalty: Penalty to reduce token repetition (default: 1.1, 1.0 = no penalty)
    """
    print("=" * 60)
    print("Qwen3-TTS VoiceDesign Audio Generation")
    print("=" * 60)
    print(f"Text: {text}")
    print(f"Voice: {voice_description}")
    print(f"Language: {language}")
    print(f"Output: {output_path}")
    print()
    
    # Check GPU
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Using device: {device}")
    if device == "cuda":
        print(f"GPU: {torch.cuda.get_device_name(0)}")
    print()
    
    # Set random seed for reproducibility
    torch.manual_seed(seed)
    if device == "cuda":
        torch.cuda.manual_seed(seed)
    np.random.seed(seed)
    
    # Load model
    print("Loading Qwen3-TTS VoiceDesign model...")
    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
        device_map=device,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32,
    )
    print("Model loaded successfully!")
    print()
    
    # Generate audio
    print("Generating audio with custom voice...")
    print(f"Consistency settings: temp={temperature}, do_sample=False, seed={seed}, repetition_penalty={repetition_penalty}")
    print(f"Sub-talker settings: dosample=False, temperature=0.0")
    print()
    wavs, sample_rate = model.generate_voice_design(
        text=text,
        language=language,
        instruct=voice_description,
        temperature=temperature,
        do_sample=False,  # Disable sampling for consistency
        repetition_penalty=repetition_penalty,  # Reduce token repetition for more consistent voice
        subtalker_dosample=False,  # Disable sampling in sub-talker (qwen3-tts-tokenizer-v2)
        subtalker_temperature=0.0,  # Deterministic sub-talker generation
    )
    print(f"Generated {len(wavs)} audio segment(s)")
    print(f"Sample rate: {sample_rate} Hz")
    print()
    
    # Save to file
    if len(wavs) > 0:
        # Concatenate all segments
        audio = np.concatenate(wavs)
        
        # Ensure int16 format
        if audio.dtype == np.float32 or audio.dtype == np.float64:
            audio = (audio * 32767).astype(np.int16)
        
        wavfile.write(output_path, sample_rate, audio)
        file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"Audio saved to: {output_path}")
        print(f"  File size: {file_size_mb:.2f} MB")
        print(f"  Duration: {len(audio) / sample_rate:.2f} seconds")
    else:
        print("ERROR: No audio generated")
    
    print("=" * 60)


if __name__ == "__main__":
    import sys
    
    # Default voice description for British female
    default_voice = "Sophisticated mature British female voice, aged 35-45, speaking slowly with deliberate pacing, warm and intimate tone, seductive and alluring quality, sultry and captivating, soft yet precise, refined and articulate with sensual undertones"
    
    # Check if voice description is provided
    if len(sys.argv) > 1:
        # Check if first argument is a voice description (starts with special marker)
        if sys.argv[1].startswith("VOICE:"):
            voice_description = sys.argv[1][6:]  # Remove "VOICE:" prefix
            text = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else "Hello! This is a test."
        else:
            voice_description = default_voice
            text = " ".join(sys.argv[1:])
    else:
        voice_description = default_voice
        text = "Hello! This is a test of the Qwen3-TTS voice design system with a British female voice."
    
    # Use TEMP folder for output to avoid cluttering User folder
    output_path = os.path.join(os.environ.get('TEMP', os.path.expanduser("~")), "qwen3_output.wav")
    
    generate_audio_voicedesign(
        text=text,
        output_path=output_path,
        voice_description=voice_description,
        language="english",
        temperature=0.1,
        seed=42,
        repetition_penalty=1.1,
    )
