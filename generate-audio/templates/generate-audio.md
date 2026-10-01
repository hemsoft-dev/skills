---
description: Generate audio with guide by default, or use stop-hook to install a repo-local Pi completion sound.
argument-hint: "[stop-hook] <audio prompt> [voice or destination instructions]"
---
Load `~/.agents/skills/generate-audio/SKILL.md` with the read tool and follow it.
Resolve the skill path against the current user's home directory.
Only a leading `stop-hook` selects repository-local Pi hook mode. Otherwise
this is ordinary audio generation. Use guide unless another voice is specified.
Honor destination instructions and do not include them in the spoken audio.
If the request is empty, ask for the audio text; do not make a paid request.

Request:
$ARGUMENTS
