# Ward structural review — proposed construction contracts

17 October 2026. Coordinator reference research: [review and source access log](reference-review.md). Construction specialist reviewed the current generator and authoritative `levels.json` against that brief. The original feasibility review below is preserved as design rationale. Its bounded construction pass is now implemented in source; fresh dynamic QA and export evidence are tracked separately. The passing progression candidate is preserved at `0032b97513ce97cafc5284b3fae9531f2f2b2d8f`.

## Intake: triage / nurse shared transfer court

Existing centres: triage `[0,0,-40]`, size `[34,9,28]`; nurse `[-40,0,-40]`, size `[26,7,24]`. Their facing walls are x=-17 and x=-27.

Replace the narrow, already ungated connector with a sealed transfer court: x[-27,-17], z[-49,-31], floor0, roof5.5. Both room faces receive matching z[-49,-31], y[0,5.5] openings with actual jambs. Provide two physical cover islands and north/south flanking lanes at least2.5m wide.

Propose a nurse-side ledge x[-30,-27], z[-47,-33], floor1.25. End stairs require a5m run and0.125m risers, subject to actual fit checks. Move one existing nurse security actor to the supported ledge, retaining its stable ID and total actor budget. The court joins an existing ungated connection and must not bypass power, credential or checkpoints.

Risk: simultaneous triage/nurse exposure increases from isolated groups to potentially ten actors. Existing supply adequacy does not prove this new engagement is fair. Check overlapping furnishings and ledge/stair lane widths before generating.

## Containment: overlook / reservoir fighting balconies

Existing centres: overlook `[0,4,0]`, size `[32,9,26]`; reservoir `[0,0,-40]`, size `[36,10,28]`. Their facing walls are z=-13 and z=-26. Existing side gallery footprints span x[4,13] and x[-13,-4], z[-26,-13], floor4.

Open the galleries to real traversal from the overlook and real firing into the reservoir. Remove the glass ends; lower the overlook opening sill to floor4. At the reservoir edge install visible solid1.4m parapets and real side guards. Corresponding reservoir apertures: x[4,13]/[-13,-4], y[4,8.3]. Retain the central gate requiring both feed flags. No movement-only invisible wall.

Use existing basin columns and balcony returns as cover. Coordinator decision after specialist review: make the reservoir firing connection open only after BOTH `isolation_a` and `isolation_b` drain the basin. Use visible physical shutters tied to those existing flags, with actual shot/visibility collision before opening and exposed-face textures after opening. Do not add a new objective or a dry enemy platform. Initial cosmetic liquid reaches3.5m above floor0, so submerged floor0 actors must not be presented as a fair early ranged threat. After draining, an existing vessel may be positioned within14m horizontal attack reach of the balcony, retaining its stable ID/count; exact placement and safe shutter motion remain construction work.

Risks: a prematurely opening shutter could activate basin enemies before draining; verify both branch orders, actual liquid/shutter synchronization, restore states and checkpoint safety. Test actual standing/crouching, item reach and every climbable object around the parapet. The undrained basin must remain inaccessible; no shortcut through a ledge or furniture step chain.

## Breach: specimens / crossfire broken transfer front

Existing centres: specimens `[80,4,40]`, size `[32,9,28]`; crossfire `[40,4,40]`, size `[32,10,30]`. Their facing walls are x=64 and x=56.

Replace the enclosed5m corridor with a sealed shared court: x[56,64], z[31,49], floor4. Open both faces z[31,49], y[4,9]. A real machinery cover island near `[60,4.75,40]`, approximately `[2,1.5,6]`, divides north/south movement lanes at least3m wide.

Propose a northern ledge z[31,34], floor5.25, depth3m, with5m-run stairs inside the adjacent rooms; actual fitting and footprint audit required. Move an existing ranged actor onto a supported ledge without changing its stable ID/count. Keep the silo vista as orientation.

This connector is already ungated after anchor A. Retain all anchors, checkpoint requirements and far-side return restrictions. Do not cut direct firing lines into anchor rooms: remote anchor destruction could break the intended descent.

## Required evidence before accepting construction

- Explicit wall cuts, floor/roof support, stairs, physical cover, all prop footprints and usable lanes; no disguised collision holes.
- Actual bidirectional hitscan and projectile contacts through apertures, with solid boundaries blocking both. Test actor attack range and line of sight separately.
- Real standing/crouching movement, ascent/descent, safe drops, anti-bypass and checkpoint safety after changed enemy activation.
- All objective dependencies, both Containment orders, no-secret supplies, shortcut direction and checkpoint Continue/Restart semantics.
- New gameplay images and a short actual combat recording. Human tactical, navigation, visual and pacing review remain necessary.

Most remaining room shells are rectangular and axial. These are bounded first structural improvements, not a claim that every map has already gained a complete spatial redesign. Preserve the passing candidate before construction; repeat relevant checks after changes rather than reusing its old receipts.

## Implemented fit decisions

- Intake uses two raised nurse ledge arms around a3.5m ground-level passage rather than blocking it with one continuous platform. Two court cover islands leave2.5m usable outer capsule-centre lanes. Ten0.125m risers use a5m stair run.
- Containment uses a0.4m solid parapet base with visible physical upper posts to1.4m and0.4m firing slots. A full solid1.4m barrier blocked the actual enemy target height; a first0.65m base passed rays but blocked real swept projectiles, so the base was lowered after native QA. The slots retain physical player exclusion without an invisible plane. Shutters require both feeds and the actual lowered liquid surface; they cannot be E-opened.
- Breach’s machine is offset to `[60,4.75,43.25]`, size `[2,1.5,4]`, keeping the original centre route clear. The two player flank paths are not a claim that the unchanged enemies coordinate flanking maneuvers.
- One existing ranged actor is repositioned per map. Actor stable IDs, types, totals64/76/84 and all three objective resources are preserved. No enemy AI, weapon tuning, source artwork or audio changes.

Static geometry probes passed44,111 checks and selected-level generation reproduced15/15 outputs byte-for-byte; these are not live route or tactical acceptance. The21 current [controlled game views](../../concepts/level-redesign-v13/index.html) include the physical shutter state change and both court perspectives. See `verification/level-redesign-v13/structural/` and `structural-runtime/` for separate evidence; older passing-candidate receipts remain historical and do not establish this new geometry.
