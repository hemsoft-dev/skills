# Qwen3-TTS Voice Profiles Configuration
# Define custom voice profiles for the play -hq command

# British Female - Sophisticated, warm, seductive (default)
$global:VOICE_BRITISH_FEMALE = "Sophisticated mature British female voice, aged 35-45, speaking slowly with deliberate pacing, warm and intimate tone, seductive and alluring quality, sultry and captivating, soft yet precise, refined and articulate with sensual undertones"

# American Female - Professional narrator
$global:VOICE_AMERICAN_PRO = "Professional American female narrator, mid-40s, clear and authoritative, news anchor quality"

# British Male - Sophisticated
$global:VOICE_BRITISH_MALE = "Sophisticated British male voice, deep and resonant, aged 40s, documentary narrator style"

# American Male - Casual and friendly
$global:VOICE_AMERICAN_CASUAL = "Casual American male, 30s, friendly and conversational, podcast host style"

# Voice profile map - used by play function
$global:VoiceProfiles = @{
    "british" = $global:VOICE_BRITISH_FEMALE
    "pro" = $global:VOICE_AMERICAN_PRO
    "brit-male" = $global:VOICE_BRITISH_MALE
    "casual" = $global:VOICE_AMERICAN_CASUAL
}

# Default voice profile
$global:DefaultVoiceProfile = "british"
