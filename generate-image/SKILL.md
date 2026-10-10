---
name: generate-image
description: V1.0 - Generate or edit images with Codex's strongest available native image generation, using the existing ChatGPT login. Use for requested raster images, concept art, Blender references, textures, mockups and image variants; replaces Antigravity image generation.
compatibility: Requires Codex native image_gen capability, directly or through an installed Codex CLI with ChatGPT authentication. No API key is required for the default path.
---

# Generate image

Use Codex's native image generation through the existing ChatGPT login. This is
the default image workflow. Do not start with Antigravity, Google image models,
a direct image API, or an API-key request.

## Route and model selection

1. If the current Codex session exposes native `image_gen`, use it directly.
2. Otherwise delegate to the installed Codex CLI and require its native
   `image_gen` tool. Do not recursively launch Codex from a delegated Codex
   session that lacks the tool. Report that missing capability instead.
3. Resolve `CODEX_HOME`, defaulting to the user's `.codex` directory. Read its
   installed `skills/.system/imagegen/SKILL.md` and relevant prompting guidance.
   Treat that vendor skill as read-only. Do not assume the parent agent and
   delegated Codex session expose the same tools.
4. Check `codex --version`, `codex exec --help` and `codex login status` before
   delegation. Use the existing ChatGPT login. If absent, ask the user to finish
   `codex login` themselves; never read auth files or request tokens in chat.
   If an SSH shell cannot find Codex, check the user's login-shell PATH or a
   verified installed executable before declaring it missing. Do not install
   or upgrade Codex without authorization.

Use the strongest image model exposed by the native runtime, not a faster or
cheaper downgrade. The verified native result on September 15, 2026 used
`gpt-image` version `2.0`. Treat that as observed provenance, not a permanent
model pin or a guarantee about future versions. Check current installed native
guidance and tool capabilities for changes.

If native generation exposes model or quality choices, choose its documented
highest-fidelity option. If it does not, use its native backend and state that
the runtime selects the image model. Do not invent a selector or claim that a
prompt guarantees a model. `codex exec --model` selects the coding agent, not
the image generator; never pass `gpt-image-2` there to try to choose an image
model. Request careful, high-fidelity work in the prompt without pretending it
is an unsupported `quality` parameter.

Running `codex exec` to reach native `image_gen` is not the vendor skill's
API-key-based Python CLI fallback. Do not use `scripts/image_gen.py` or change
the billing/authentication path unless the user explicitly authorizes it. If
native generation fails or is unavailable, retain the error and report it;
do not silently change provider, downgrade models or retry indefinitely.

If Codex's configured default coding model is rejected for the ChatGPT login
("model is not supported when using Codex with a ChatGPT account"), pass a
supported coding model per run (for example `--model gpt-6-astra`, verified
2026-10-03) instead of changing the global config. Find the model that recent
successful runs used in `CODEX_HOME/sessions`.

## Prepare the request

- Read project asset rules and identify whether this is a new image, an edit,
  or variants. Prefer editing existing vector/code-native assets when that is
  what the user requested, rather than replacing them with generated bitmaps.
- Record subject, intended use, composition, aspect ratio, materials, lighting,
  required text, constraints and requested destination. Preserve a detailed
  user prompt; clarify only missing choices that materially affect the result.
- Inspect every supplied image and label it as a reference, edit target or
  supporting input. Attach it to the Codex request, using `--image` for local
  files when delegating, or have native Codex load it before editing. A path
  mentioned in prose alone does not prove the generator saw the image.
- Preserve originals and use versioned output names. Do not overwrite accepted
  art without explicit replacement authority. Prefer the project's asset
  directory; otherwise use a task-specific folder under `output/imagegen/`.
- For Blender concepts, load the installed global
  [blender-game-assets skill](https://github.com/hemsoft-dev/skills/blob/main/blender-game-assets/SKILL.md)
  for measured dimensions, coherent views, material studies and approval gates.
  Generated dimensions are guidance, not CAD measurements.
- An attached reference strongly anchors body shape and age. For a large
  change, state it explicitly ("clearly fitter than the reference"), or drop
  the reference and accept a new face.
- Realistic human body references in underwear only are usually blocked by the
  output content filter as sexual. Athletic coverage passes: a sports top and
  short or mid-thigh shorts, bare-chested men in mid-thigh shorts, with a tank
  top as the fallback. Keep the wording clinical and avoid suggestive terms.
- If a request without an image keeps getting blocked, attach a sheet that
  already passed as "style and clothing reference only; the subject is a
  different person". That got female-05 through after four blocks.
- For batch runs, keep request, receipt and log files in a persistent folder
  (for example the worktree's ignored `Saved/`), not session scratch, which can
  disappear mid-run. Parallel `Start-Job` runs of `codex exec` work. Retry
  blocked items once with softer wording and report any that still fail.

## Delegate from another agent

Create a narrow prompt file and a task workspace. Use the normal sandbox and
approval controls. Do not use unrestricted sandbox modes, approval bypasses,
ignore-rules flags or copied credentials to make generation work.

PowerShell, using absolute paths for the placeholders:

```powershell
Get-Content -LiteralPath '<request-file>' -Raw |
    codex exec --sandbox workspace-write --skip-git-repo-check `
        --cd '<task-workspace>' --output-last-message '<receipt-file>' -
```

POSIX shell:

```sh
codex exec --sandbox workspace-write --skip-git-repo-check \
  --cd '<task-workspace>' --output-last-message '<receipt-file>' - < '<request-file>'
```

For references or edits, add `--image '<input-image>'` before the final `-`.
Use only the inputs and write locations needed for the task. Do not change the
parent's model or global Codex settings. Keep raw execution logs local and
bounded; they may contain prompts or private reference details.

The delegated prompt must include:

```text
Use the installed Codex imagegen guidance and your native image_gen tool.
This is native generation via the existing ChatGPT login, not the Python/API
fallback. Do not delegate again, request an API key or switch provider.
Use the strongest available native image capability without inventing controls.

Image request: <exact prompt and constraints>
Inputs and roles: <attached images, or none>
Deliverable: <new absolute image path inside the task workspace>

Generate and inspect the image, then return the exact native output path so
the calling agent can copy it to the deliverable destination without overwriting
existing files. Native output may start under CODEX_HOME/generated_images; do
not assume a tool destination argument exists. Do not modify unrelated project
files or settings.
Return the native path, actual dimensions, native tool used, generator model
only if supported by tool output or image provenance, and any unmet constraints.
If the tool is unavailable or fails, report the failure instead of substituting
a drawing script, placeholder or another provider.
```

## Verify and deliver

1. Confirm the delivered file exists, is a decodable image, and has the reported
   dimensions. A delegated success message alone is insufficient. Match SHA-256
   when copying the selected original, rather than silently resizing it. After
   delegation, the calling agent should make and open the workspace copy itself.
   On Windows, a sandbox-created copy can be unreadable outside that sandbox.
   If that happens, retain the error and copy the accessible native original to
   a fresh destination in the caller's normal context. Do not relax sandbox or
   filesystem permissions, overwrite files or regenerate an image to fix a
   delivery-permission problem.
2. Inspect the actual image for composition, reference fidelity, text accuracy,
   material detail and unwanted artifacts. For edits, compare against the input
   and check unchanged regions. Check alpha pixels for transparency requests;
   a painted checkerboard is not transparency. Iterate with a targeted change
   when the requested constraints are not met.
3. Keep the final project image in the workspace, not only in Codex's generated
   image cache. Retain the original-resolution selected output and record the
   prompt, inputs, date, tool, reported model or "not exposed", dimensions,
   SHA-256, intended use and approval state in the existing provenance format.
   Do not infer the image model from the coding agent's model name.
4. Link the saved image and report unresolved constraints. For concepts, get
   approval before downstream modeling or final asset use. Image generation
   does not establish third-party rights or exclusive copyright.

## History

After using or changing this skill, append `## HH:MM - {Action Taken}` and a
one-line result to `History/{YYYY-MM-DD}.md`. Obtain the timestamp from the shell
in Eastern Time. Record whether the retrospective found a reusable improvement.
Do not log credentials or private image/prompt contents in shared skill history.
