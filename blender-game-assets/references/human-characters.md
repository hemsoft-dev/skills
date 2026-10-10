# Human characters from reference sheets

Lessons from building preset avatars from AI-generated front/side/back sheets
(Hoarder's Heaven #153, October 2026, Blender 5.2).

## Choosing a base

- A realistic human cannot be sculpted from scratch by script. Start from a
  parametric base and fit it to the sheet.
- MPFB 2.0.17 (free, CC0 output, GPL code) fits well by measurement but reads
  smooth and doll-like. Faces, skin and hair need heavy work.
- Human Generator 4.0.x (paid, $128 Commercial for games, one user, assets
  must not be shareable or extractable) starts realistic: skin, eyes and strand
  hair. It is scriptable through `from HumGen3D import Human` and works headless
  in Blender 5.2.
- Check the project's earlier evaluation records before recommending a base;
  a tool may already have been rejected.

## Sheet masks

- Thresholding against the backdrop fails: contact shadows read as body and
  white fabric reads as backdrop. Use torchvision DeepLabV3-ResNet101 (person
  class 15) in system Python; PyTorch with CUDA was available.
- Split the three views at empty column gaps, then flood-fill holes from the
  border.

## Fitting the body

- Compare central-span width (front) and depth (side) profiles, normalized by
  feet-to-neck height so hair and bald bases do not distort the scale.
- Measure the arm angle from the sheet (fit a line through the separate arm
  run) and pose the rig to match; the silhouette metric is blind to it.
- Outline fitting alone yields soft or contradictory slider mixes (skinny and
  overweight both high). Fix art-direction sliders (muscle, bust, muscle groups)
  from the brief; fit only proportion sliders, with a penalty on extremes.
- Always judge with a rendered side-by-side; a good profile score can still
  look wrong.

## MPFB specifics

- Entry points: `HumanService.create_human(macro_detail_dict=...)`,
  `HumanObjectProperties.set_value` plus `TargetService.reapply_macro_details`,
  `TargetService.load_target`, `HumanService.add_builtin_rig(basemesh,
  "game_engine")` (Unreal mannequin bone names).
- The mesh contains helper shells (tights, skirt, hair). Restrict ray casts and
  projection to the `body` vertex group used by its mask modifier.
- `bpy.ops.wm.read_factory_settings` unloads the extension; delete objects
  instead.

## Human Generator specifics

- Headless install: set the library path with a trailing backslash, then
  `bpy.ops.hg3d.cpackselect("EXEC_DEFAULT", directory=..., files=[{"name": f}])`
  and `bpy.ops.hg3d.cpackinstall()`; save user preferences.
- Body sliders: `human.body.keys` (`key.value`), face: `human.face.keys`,
  height: `human.height.set(cm)`. Body keys change height afterwards, so set it
  last and correct by measuring the mesh.
- `human.hair.face_hair` raises `NotImplementedError` for women.
- Built-in underwear (`skin.set_underwear`) colour comes from a texture; plan
  separate base-layer garments instead.
- The rig uses Rigify-style names (`upper_arm.L`); rename for Unreal with
  `human.process.rename_bones_from_json`.

## Projection texturing

- Projecting sheet pixels onto a fitted body transfers detail but needs
  pixel-accurate pose and silhouette alignment, and bakes in studio lighting.
  Treat it as an experiment, not a pipeline.
- Cycles bakes are scene-linear; convert to sRGB before saving a PNG.

## Converting to the Unreal mannequin skeleton

- Append the mannequin armature from a template .blend, set every edit bone `use_connect = False` before moving
  joints (connected children are dragged by their parents), keep each bone's template orientation, and verify every
  head lands on its target.
- Map Human Generator deform bones to mannequin bones; unmapped deform bones inherit their nearest mapped ancestor.
  Skip vertex groups that are not deform bones (masks, regions such as `mask_torso`, `lip_*_vg`) — defaulting them to
  `head` made knees follow the head. Map `pelvis.L/R` and `heel.L/R` explicitly.
- Bake meshes in rest pose with `bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True)` and
  copy vertex-group names from the source object; bind rigidly attached parts (eyes) to their parent bone.
- Run a bend test (knees, elbows, shoulders, spine) before any engine import; mannequin bones bend about local Z.
