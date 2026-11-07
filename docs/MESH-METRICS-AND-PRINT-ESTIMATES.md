# Mesh quantities and generic FFF estimates

`measureMeshes(root, {visibleOnly: true})` expects the current world transform to express millimetres. It counts source meshes under the supplied file, component or scene, including the selected object's ancestor visibility. Application reference objects must live outside that root.

Vertices are welded by quantizing local coordinates at 10⁻⁷ of the local bounding-box extent. Every undirected triangle edge must have exactly two incident faces with opposite directions. Degenerate triangles, invalid coordinates or indices, boundary edges, nonmanifold edges and inconsistent winding prevent a volume result. Open surfaces can still report triangle surface area. Skinning, active morph targets and instancing are explicitly unsupported rather than silently measured incorrectly.

The signed tetrahedron volume of each triangle is `a · (b × c) / 6`, evaluated near the local bounding-box centre for numerical stability. The absolute total is scaled by the absolute determinant of the world transform. Surface triangles are transformed separately, so nonuniform scaling and rotations affect areas and Z height correctly. Horizontal and vertical areas are absolute projected surface areas, not a classification into horizontal and vertical faces.

Mesh volumes are added. This is **not a Boolean union**: overlaps between components and redundant internal surfaces are not removed. The edge test does not detect self-intersection or certify a valid CAD solid. Consistently oriented nested shells contribute signed cavity volume within one mesh; shells in separate meshes remain additive. Intersecting or malformed shells can produce a misleading volume even if every edge passes the topology test. The UI must retain this qualification. Invisible parts are excluded by default.

Topology and local triangles are cached by geometry, attribute identity/count and Three.js update version. Attribute edits must set `needsUpdate = true`, as required by Three.js. Transformed areas and local-relative bounds are cached by mesh and linear transform; translation can reuse them. Bounds are subsequently translated and united, so the height of a group still follows relative component placement.

## Printing heuristic

`estimatePrint(metrics, options)` accepts a generic material code (`pla`, `petg`, `abs`, `asa`, `tpu`, `pa`, `pc`), layer height and nozzle in mm, infill in percent, wall and solid-layer counts, nominal speed in mm/s and volumetric flow in mm³/s. Material values are illustrative assumptions for the estimator, **not vendor recommendations or calibrated presets**. They add no density or mass claim. User values override the starting assumptions.

The deposited shell approximation is:

- Vertical projected surface area × wall count × extrusion width.
- Horizontal projected surface area × top/bottom layer count × layer height.
- Extrusion width is assumed to be 1.1 × nozzle diameter.
- The combined shell volume is capped at the mesh volume.
- The remaining volume is multiplied by the infill fraction.

Deposition time divides this material volume by the smaller of the flow limit and `nominal speed × extrusion width × layer height`. A heuristic factor from 1.2 to 1.8 accounts for travel/short moves, followed by two seconds per layer. The displayed range spans 65–150% of that central calculation; it is **not a confidence interval or a guaranteed bound**.

No toolpath is sliced. Supports, brim/raft, purge, heating, tool changes, cooling, real acceleration limits, exact wall offsets, small features and infill geometry are not simulated. Actual printer/slicer times may lie outside the range. Open or invalid meshes and invalid process inputs return an unavailable estimate, not a fabricated time. Estimates and overrides stay in the viewing session; source models are not rewritten or uploaded.

Run `node scripts/mesh-print-test.mjs` to exercise known quantities, transforms, visibility, topology rejection, cache invalidation and estimator monotonicity.
