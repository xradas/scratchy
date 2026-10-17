# Intake v7: room presentation

The visual target remains the approved `concepts/visual-v2/corrupted-biotech/scene.png`, inspected before implementation. Its useful spatial cues are layered steel, dense overhead services, warm practical lights against restrained sick-green equipment, clearly framed movement openings and strong foreground/middle/background separation. This pass implements those architectural cues with existing production assets; it does not claim a pixel-identical reproduction of the concept.

## Before and after

The v6 room programme already supplies medical furniture, but rooms share a largely unarticulated ceiling and similar green equipment pools. The new section adds identifiable overhead workflows rather than another layer of generic floor crates:

| Room | Added identity | Readability goal |
|---|---|---|
| Patient intake | Reception canopy, warm desk-edge practical, two offset overhead service runs | A recognisable arrival/work point with an unobstructed route into decontamination |
| Decontamination | High air plenums/nozzles and compact cold practical | Equipment reads as room-wide air handling without a false impassable spray gate |
| Emergency triage | Suspended structural gantries above the sunken court and restrained medical bay pools | Show the floor-height difference; keep enemies and gallery retreat routes visible |
| Diagnostics | Suspended scanner carriage/track with a cold lens | A different clinical function from storage or reception |
| Operating theatre | Twin circular surgical heads above the **actual furnished surgical table** | A memorable local light landmark, not an arbitrary room-centre decoration |
| Sterile supply return | Ceiling trolley rails and crossbar over the existing storage fittings | A recognisable equipment-return workflow without extra crates or blocked circulation |

Every room receives textured steel ribs, paired uneven service runs with clamps, and offset warm/cold practicals. Existing native production materials are reused unchanged: the architecture-v2 material registrations and the sixteen-cell `assets/materials/room-props-v6/pale_ward-atlas.png` registration. Box surfaces use the existing `room_prop_local_uv.gdshader` face-normalised atlas mapping; cylindrical surgical heads use the existing `_cyl` variant. No raster asset is generated, resampled, cropped or repainted by this component. No new external asset or license is introduced.

## Integration contract

Call `intake_presentation_v7.decorate(sc)` **once after** ordinary `room_program_v6.furnish`. The function is a no-op except for `campaign_level_id == "pale_ward_01"`; it fails clearly on duplicate application or missing material registration/theatre table. It returns a serialisable report and also exposes it as `sc.intake_presentation_v7`.

The six top-level `IntakePresentation_<room>` groups carry `presentation_v7`, `room_id` and `room_function` metadata. Their local coordinates are reconstructed from `sc.stage` room centres, final footprints and floor heights on every run. Table light alignment is taken from the actual authored surgical-table root position. The component does not modify stage data, material registrations, progression, pickups, enemy positions or other maps.

The report contains 117 physical parts, 15 lens inlays and 15 local lights. Every physical part uses Scene's matching visible BoxMesh/BoxShape3D or CylinderMesh/CylinderShape3D dimensions and `armor` hit material. There are no floor-level additions. Lens inlays sit immediately within or below physical housings and add no navigation obstacle. No global environment/ambient change is made.

## Clearance and render review

All physical additions begin at least 3.47 m above the room floor. Decontamination plenums/nozzles start at 4.37 m or higher, above the original 2.5 m service balcony rise plus actor height. Triage gantries begin at 6.025 m, above the raised gallery. Roof runs remain close to the ceiling. Existing portal thresholds, stairs, floor retreat lanes and pickup/control mechanisms receive no new floor obstruction.

The report's `capture_targets` specifies six room-relative working views plus the actual-table surgical landmark. These are **candidate camera poses**, requiring coordinator native ray/viewport checking; they are not asserted collision-free gameplay camera placements. Capture arrival/decon transition, triage from its descending approach, diagnostics from its arrival door, theatre table/light, and supply from the return-side doorway. Use native 640×360 world frames and ordinary gameplay eye height, retaining a clearly labelled controlled view when actors are hidden.

Acceptance requires the canopy/scanner/surgical light/trolley rails to be visually distinct, enemies readable under the combined existing and new lighting, and no ceiling intersections on the final room layout. Check the actual game mix while traversing; this art component adds no audio. Additional local lights have finite ranges (6–10 m), and only the surgical spotlight adds shadows. Performance must be measured on the final combined build rather than inferred from the isolated parser check.

## Bounded verification

An isolated scene built from the preserved Intake scene and this component parsed and instantiated in the pinned Godot 4.7.2 headless runtime. It contained six presentation groups and 117 physical parts; native inspection checked every new body had matching visible/collision dimensions. Python checks covered the room guard, duplicate-call rejection, material reuse and minimum overhead bound. These checks establish authoring/parse consistency, **not** final-layout traversal, visual approval, campaign progression or performance. Those remain integration checks owned by the coordinator and independent playtest roles.
