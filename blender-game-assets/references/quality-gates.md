# Game asset quality gates

Apply only the gates relevant to the asset. Record the actual result instead of
marking unchecked work as complete.

## Design

- The asset matches the defining traits of the accepted brief and selected
  references as closely as feasible within the agreed budget. Matching the
  object category or broad silhouette alone is insufficient.
- Final side-by-side reference/engine views and detail crops prove the match at
  gameplay and closest supported distances. Evidence identifies the delivered
  revision; neutral-light comparisons distinguish asset flaws from lighting.
- Every material visual deviation has an explicit user decision supported by
  the alternatives tried and their measured costs. Unaccepted deviations remain
  unresolved, even if technical tests pass or the concept was approved.
- Front, side, back, and gameplay silhouettes remain coherent.
- Real dimensions, orientation, and pivot are recorded.
- Generated references contain no unresolved construction contradictions.

## Blender source

- The source `.blend` opens without missing linked files or textures.
- Objects and collections use meaningful project names.
- Location, rotation, scale, origin, and unit settings are intentional.
- Face orientation and normals are correct.
- The delivery mesh has no accidental duplicate, loose, hidden, or internal
  geometry.
- Topology supports required shading, deformation, and camera distance.
- Nondestructive source and destructive export states are not confused.

## UVs and materials

- UV seams, texel density, padding, orientation, and intentional overlaps pass
  visual inspection.
- Every material slot is used and necessary.
- Base Color contains no baked lighting.
- Non-color maps use non-color data handling.
- Normal orientation, roughness response, metallic values, opacity, and packed
  channels are correct.
- Textures tile or terminate cleanly and remain stable through mip levels.
- Bake cages and high-to-low projection produce no visible skew or artifacts.

## Game readiness

- Actual geometry, materials, textures and asset/source bytes are compared with
  the brief's budget. Cooked size, resident memory and frame cost are measured
  where available; missing measurements are marked unmeasured, not passed.
  An unmeasured required budget cannot be reported as satisfied.
- Added detail produces a visible improvement at the required distances for a
  justified cost. Cheaper representations were evaluated before accepting a
  material fidelity loss; smaller files alone are not a successful outcome.
- Collision matches gameplay needs without copying render complexity by
  default.
- LODs, Nanite, cards, or another distance strategy match the asset type.
- Foliage validates transparency, overdraw, wind, density, shadows, and distance
  behavior.
- Skeletal assets validate hierarchy, bind pose, weights, deformation, root,
  animation scale, and retargeting requirements.
- Modular pieces snap on the project's grid and hide seams at intended joins.
- Sockets, variants, damage states, and interaction clearances work when
  required.

## Export and engine import

- The export contains only intended objects and uses a documented preset.
- Reimporting the export into a clean test scene preserves scale, orientation,
  normals, UVs, material order, animation, and collision.
- The target engine import has correct asset names and destination paths.
- Engine lighting reveals no unexpected seams, shading errors, or material
  response.
- A representative gameplay placement proves collision and interaction.
- Performance claims come from the target engine and representative density,
  not Blender viewport speed.

## Delivery

- Editable source, exports, texture sources, final maps, previews, and import
  notes are present when applicable.
- Prompts, generated references, external sources, modifications, licenses, and
  authorship are recorded.
- A turntable or equivalent review set shows the final asset, wireframe, and key
  material channels.
- Known limitations and deferred work are explicit. The final evidence includes
  the fidelity comparison, costs against budget and accepted compromises.
- Technical readiness and visual fidelity have separate results. Do not declare
  completion while a required comparison or material compromise decision is
  missing.
