# Qwen3-TTS File Organization - Cleanup Summary

## What Was Done

### Files Moved to Proper Locations

1. **Scripts moved to `C:\Users\User\.claude\skills\qwen3-tts\scripts\`:**
   - `qwen3_tts_voicedesign.py` - VoiceDesign generation script with consistency parameters
   - `voice_profiles.ps1` - Voice profile definitions (british, pro, brit-male, casual)

2. **PowerShell Profile Updated:**
   - Voice profiles now loaded from: `$env:USERPROFILE\.claude\skills\qwen3-tts\scripts\voice_profiles.ps1`
   - `play -hq` command now uses script from: `$env:USERPROFILE\.claude\skills\qwen3-tts\scripts\qwen3_tts_voicedesign.py`
   - Output files now go to TEMP folder instead of User folder

3. **SKILL.md Updated:**
   - Added documentation for new scripts
   - Added "Voice Consistency Parameters" section explaining consistency settings

### Files to Clean Up

Run this command to clean up old files from User folder:

```powershell
C:\Users\User\.claude\skills\qwen3-tts\scripts\cleanup_user_folder.ps1
```

This will delete:

- Old scripts: `qwen3_voice_profiles.ps1`, `qwen3_tts_voicedesign.py`, `qwen3_tts_clone.py`
- Test files: `test_voice_consistency.ps1`, `consistency_test_*.wav`
- Temporary files: `qwen3_output.wav`, `qwen3_reference_voice.wav`, `qwen3_consistency_notes.md`

### New File Locations

**Scripts:**

- `C:\Users\User\.claude\skills\qwen3-tts\scripts\qwen3_tts_voicedesign.py`
- `C:\Users\User\.claude\skills\qwen3-tts\scripts\voice_profiles.ps1`
- `C:\Users\User\.claude\skills\qwen3-tts\scripts\cleanup_user_folder.ps1`

**Output Files:**

- Temporary output: `$env:TEMP\qwen3_output.wav` (auto-deleted after playback)
- Saved output: User-specified path with `play -hq -save <path>` command

### Voice Consistency Improvements

Enhanced `qwen3_tts_voicedesign.py` with these parameters:

- `temperature=0.1` - Very low randomness
- `do_sample=False` - Deterministic generation
- `seed=42` - Fixed random seed
- `repetition_penalty=1.1` - Reduces token repetition (NEW)
- `subtalker_dosample=False` - Deterministic sub-talker (NEW)
- `subtalker_temperature=0.0` - Zero randomness in sub-talker (NEW)

These settings work together to minimize voice variation between generations.

## Next Steps

1. **Reload PowerShell profile** to pick up changes:

   ```powershell
   . $PROFILE
   ```

2. **Run cleanup script** to delete old files:

   ```powershell
   C:\Users\User\.claude\skills\qwen3-tts\scripts\cleanup_user_folder.ps1
   ```

3. **Test the updated system**:

   ```powershell
   play -hq "Testing the new file organization"
   ```

4. **Verify output location**:
   - Check that `qwen3_output.wav` is now in `$env:TEMP` instead of User folder
   - Verify no wav files are piling up in User folder

## Benefits

- User folder stays clean (no script or wav file clutter)
- All qwen3-tts related files are in one skill folder
- SKILL.md documents all scripts and their purpose
- Easier to maintain and update long-term
- Consistency improvements for better voice quality
