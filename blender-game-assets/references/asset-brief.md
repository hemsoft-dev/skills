# Asset brief

Draft the brief from project evidence first. Ask only for missing answers that
would materially change the asset.

## Minimum brief

| Field | What to record |
| --- | --- |
| Asset | Canonical name and asset type |
| Purpose | Decorative, interactive, gatherable, building piece, equipment, character, or surface |
| Target | Engine and version, platform, destination folder, and naming rules |
| Art direction | Style, mood, references, materials, age, wear, and prohibited traits |
| Dimensions | Real height, width, depth, pivot, orientation, and required clearances |
| Viewing conditions | Typical distance, closest distance, camera type, and lighting |
| Geometry | Static or Skeletal Mesh, silhouette, variants, modularity, and deformation needs |
| Materials | Substances, texture sets, resolution, texel density, transparency, and channel packing |
| Gameplay | Collision, interaction, sockets, damage states, animation, and replication relevance |
| Performance | Representative scene, density, geometry budget, material slots, LOD or Nanite plan |
| Delivery | Source, exports, textures, previews, manifest, and engine verification |
| Provenance | Generated, authored, scanned, purchased, or modified inputs and their licenses |

Do not require the user to supply technical budgets they have not established.
Propose a measurable starting point based on project evidence, then label it as
a proposal until validated in the target scene.

## Vocabulary checkpoints

| User wording | Possible meanings | Ask when |
| --- | --- | --- |
| Asset | Any saved content, a mesh, or a complete interactive object | The delivery could be one file or a Blueprint assembly |
| Model | Concept image, Static Mesh, Skeletal Mesh, or full textured asset | Rigging, animation, or output format changes |
| Texture | One image map, a PBR texture set, a Material, or the whole visible treatment | The user may expect changed shape or a complete Material |
| Surface | A PBR material treatment or the geometric faces of a mesh | Geometry versus appearance changes the work |
| Object | Blender object, Unreal Actor, mesh, or gameplay object | Components or behavior may be required |
| Terrain | Unreal Landscape, heightmap, terrain mesh, or surface material | Sculpting, painting, collision, and export differ |
| Tree | Decorative foliage, Static Mesh, or gatherable Blueprint Actor | Collision, interaction, destruction, or variants differ |
| Realistic | Physically plausible materials, photoreal geometry, or grounded art direction | Reference target and performance cost are unclear |

Good clarification:

> By "new texture for the rock," do you want a realistic PBR surface on the
> existing shape, or a new rock mesh and material? I recommend the first if the
> current silhouette already works.

Poor clarification:

> What do you mean by texture?

The good version teaches the vocabulary, narrows the decision, and recommends a
path.
