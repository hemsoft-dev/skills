---
name: blender-game-assets
description: V1.3 - Creates professional game-ready assets by combining high-fidelity image generation, Blender modeling, and engine-specific validation. Use for concept sheets, surfaces, Static Meshes, props, modular kits, foliage, optimization, and Unreal delivery.
disable-model-invocation: true
compatibility: Requires an image-generation capability for concept work. Build, validation, and export phases require Blender on PATH or at a verified absolute path. Engine delivery requires the target project and engine version.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the blender-game-assets directory, verify that history logging occurred.

            Check whether History/{YYYY-MM-DD}.md contains:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate time from the shell, never an estimate

            If the entry is missing or incomplete, state exactly what must be added.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping after blender-game-assets was used, verify:

            1. History/{YYYY-MM-DD}.md contains an accurate interaction entry.
            2. The entry states whether the retrospective found a reusable improvement.
            3. Every promised artifact exists and every reported validation actually ran.

            Block completion when any requirement is missing.
---

# Blender game assets

Turn an asset idea into a traceable, game-ready delivery. Use generated imagery
for art direction and reference, Blender for authored geometry and rendering,
and the target engine for the final proof.

## Working principles

- Treat art direction as a human decision. Present clear options when taste or
  product identity is undecided.
- Treat generated images as references unless the user explicitly requests a
  final two-dimensional asset and its license and technical requirements allow
  that use.
- Do not promise unlimited quality. Image models may invent inconsistent
  geometry, lighting, scale, and details between views.
- Call an asset professional only after proving its scale, silhouette,
  geometry, UVs, materials, collision, export, and engine result.
- Preserve editable source files. Never overwrite the only `.blend`, generated
  reference, texture source, or export.
- Do not install Blender, add-ons, models, or third-party assets without direct
  approval.
- Record the source and license of every external or generated input.

## Start every request

1. Read applicable project instructions, art direction, asset ledger, naming
   rules, `VOCABULARY.md`, and `CONTEXT.md` when present.
2. Identify the requested phase: brief, concept, build, surface, optimize,
   validate, or deliver.
3. Detect the available image-generation capability and Blender executable.
4. Record the target engine, engine version, platform, asset destination, and
   repository state.
5. Draft the asset brief using
   [references/asset-brief.md](references/asset-brief.md). Fill safe defaults
   from project evidence before asking questions.

If Blender is unavailable, complete useful brief and concept work, then report
the exact missing dependency. Do not pretend a `.blend`, mesh, render, or export
was produced.

Before version-sensitive Blender scripting or engine export, fetch current
official documentation for the installed Blender version and target engine.
Project-required documentation tools take precedence over general web search.

## Clarify vocabulary without slowing the work

Use the project's canonical terms. When the user's wording is fuzzy:

- State the likely interpretation and proceed when the choice is reversible.
- Ask one concise question when the term changes the deliverable, cost, or
  engine behavior.
- Offer the precise term as help, never as a correction for its own sake.
- Ask no more than three questions in one round. Put the recommended choice
  first and explain what changes.

Examples:

- "By texture, do you mean a PBR surface for the existing mesh, or a new mesh
  and material? I recommend the PBR surface if the shape already works."
- "Should this tree be decorative foliage or a gatherable Blueprint Actor? The
  second needs gameplay collision, interaction, and damaged states."
- "When you say model, do you want concept images, a Static Mesh, or a rigged
  Skeletal Mesh?"

Do not ask about harmless synonyms when the intended result is already clear.

## Generate reference imagery

Use the highest-fidelity image-generation capability available in the current
runtime. Do not invent a quality setting that the tool does not expose. Improve
quality through a precise brief, strong references, controlled iteration, and
inspection at original detail.

For a three-dimensional asset, generate a coherent reference package when it
will materially improve the model:

- one hero view that establishes the design;
- front, side, and back views with a neutral camera and background;
- close views of construction, wear, joints, and material transitions;
- a material and color reference with named substances;
- a silhouette sheet or variants when the shape is undecided.

Generated views are not dimensionally trustworthy. Set real dimensions in the
brief and build the Blender blockout from those measurements. Do not trace
perspective distortion as if it were an orthographic drawing.

For image edits, inspect every source image first, include every required source
view, and change one design variable at a time. Keep unrelated conversation
images out of the edit context.

Save the selected references at original resolution with their prompts,
generation date, tool or model when available, and intended use. Reject images
with inconsistent construction that cannot exist in three dimensions.

## Build in Blender

1. Set real-world units, target dimensions, orientation, origin, and pivot.
2. Block out the full silhouette before adding detail.
3. Resolve any shape decision that would make later work disposable.
4. Keep an editable source version with nondestructive modifiers where useful.
5. Build clean topology appropriate to deformation, baking, shading, and camera
   distance. Do not chase polygon counts without a target budget.
6. Apply transforms deliberately. Preserve the source before destructive
   conversion, triangulation, modifier application, or remeshing.
7. Set face orientation, custom normals when needed, smoothing, and hard edges.
8. Create UVs with consistent texel density, intentional seams, enough padding,
   and no accidental overlap.
9. Bake from a named source mesh to a named delivery mesh when a high-to-low
   workflow is justified.
10. Name objects, collections, materials, textures, collision, sockets, and LODs
    according to the target project's rules.

Use Blender for distinctive forms, props, building pieces, and controlled
variations. Treat foliage, hair, cloth, skeletal assets, photogrammetry, and
procedural generation as specialized work that requires an explicit brief and
extra validation.

## Create materials and surfaces

- Use physically based values and test them under more than one lighting setup.
- Keep Base Color free of baked highlights and shadows.
- Treat Base Color as color data and Normal, Roughness, Metallic, Ambient
  Occlusion, masks, and height as non-color data.
- Keep real-world texture scale and project texel density consistent.
- Verify tiling, seams, mip behavior, compression, and channel packing in the
  target engine.
- Do not treat an image-generated color texture as a complete PBR surface.
  Derive or author the supporting maps, then inspect each channel.
- Keep the number of material slots intentional. Extra slots add engine cost
  and complicate batching.

For a surface-only request, do not create a production mesh merely to display
the surface. Use a test plane, sphere, or project preview mesh and deliver the
PBR texture set plus Material setup.

## Prepare for the target engine

Use project naming rules when they exist. For Unreal projects without stronger
rules, follow current Epic-style prefixes such as `SM_`, `SK_`, `M_`, `MI_`,
`T_`, and `BP_`.

Before export, decide and verify:

- real dimensions, axis conversion, transforms, origin, and pivot;
- render mesh, material slots, UV sets, vertex colors, and normals;
- simple or complex collision and the target engine's collision naming;
- Nanite, authored LODs, or another distance strategy;
- sockets, animation skeleton, morph targets, or variants when required;
- export format and settings supported by the target engine version.

An export file is not completion. Import it into the target engine and inspect
scale, orientation, shading, textures, collision, material slots, LOD or Nanite
behavior, and gameplay use. Measure performance in a representative scene
before claiming it meets budget.

## Compare in the engine

For environment work based on a fixed target image, build a deterministic
engine comparison loop before making fine art changes:

1. Fix the map, camera transform, field of view, resolution, scalability, and
   post-process overrides in a repeatable offscreen capture command.
2. Keep an append-only iteration log. Record a pass only when the engine result
   improves. Blender-only renders and rejected experiments do not count.
3. Compare the target and engine capture at original detail after each material,
   placement, lighting, or composition change.
4. Save the export-ready `.blend` before moving objects into a preview lineup.
5. Verify generated alpha textures by file format, corner pixels, and an
   in-engine opacity-mask test. Reject baked checkerboards.
6. Expect FBX lightmap generation to replace or reorder secondary UV channels.
   Use a separate mesh for a path or disable lightmap UV generation when exact
   imported channels matter.
7. Prefer Static Mesh Foliage instancing for dense decorative sets. Verify the
   final Hierarchical Instanced Static Mesh counts after a fresh map load.
8. Crop dark root pixels in card UVs instead of hiding them with larger path
   clearances. Do not enable full dynamic shadows on crossed grass cards unless
   the engine capture proves their silhouettes look natural.
9. For mid-distance forest edges, a small set of photoreal whole-tree alpha
   cutouts can outperform procedural meshes built from repeated branch cards.
   Inspect crossed-card seams from the initial gameplay camera, control their
   orientation, and disable proxy shadows when they create black sheets or
   self-shadow artifacts.
10. When a terrain mask repeats, wraps, or changes channels after import, bake
    the blend weight into a named terrain vertex-color layer. Verify in engine
    that it produces one continuous route before removing the older overlay.
11. Keep one authoritative ground surface. If a template Landscape overlaps an
    authored replacement terrain, remove or disable its rendering and collision;
    a flat foreground seam can be evidence of two surfaces occupying the same
    space.
12. If image generation bakes a checkerboard into an attempted transparent
    texture, regenerate the subject on a uniform key color. Crop each atlas cell
    tightly and derive the opacity mask from the cleanest color channel in the
    engine; accept the workaround only after an engine capture proves the key is
    gone without erasing thin stems or leaves.
13. Build realistic meadows from several plant roles at different scales and
    densities: fine grass as the dense base, taller grass and leaves as the
    middle layer, then clustered flowers and seed heads. Author upward foliage
    normals where the export path preserves them, keep individual clumps small,
    and add deterministic edge dressing around paths and rock bases.
14. Compare procedural placement, clearance, and height-sampling math with the
    imported mesh in engine space. FBX axis conversion can mirror a Blender axis
    even when scale and orientation look correct; apply the same conversion to
    every analytical curve, exclusion test, and surface sampler that must follow
    the converted geometry.
15. Judge hidden shadow proxies from the fixed gameplay camera. Crossed
    whole-tree cards can cast opaque card-plane bands, and simplified canopy
    proxies can still create dark stripes. Remove a proxy when the engine
    capture exposes its construction instead of producing natural broken shade.

When a generator must preserve an accepted image-generated texture, make that
rule explicit in code and prove it with a hash before and after a full rebuild.
Rebuilding source packages must not silently replace selected art.

## Validate and deliver

Read [references/quality-gates.md](references/quality-gates.md) before declaring
an asset complete. Run every applicable automated check, create a turntable or
equivalent review render, and inspect the final engine import.

Deliver only applicable artifacts:

- editable `.blend` source;
- engine import file such as FBX or glTF;
- texture sources and final PBR maps;
- selected concept and reference images;
- preview renders, wireframe, UV view, and material-channel checks;
- provenance and license record;
- compact import settings and validation results.

Report the interpreted brief, vocabulary decisions, files created, dimensions,
technical specifications, validations run, engine result, and remaining risks.
Never ask the user to test something without an exact action and expected
result recorded in the target project's instructions.

## History

After using this skill, append `## HH:MM - {Action Taken}` and a one-line
summary to `History/{YYYY-MM-DD}.md`. State whether the retrospective found a
reusable improvement. Obtain the time from the shell, never estimate it.
