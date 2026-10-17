# Volumetric gore — v12

Start from the delivered v11b staff/lighting build, source baseline `7b2b316313a34dd9928862317bf18a39db24859d`. The coordinator owns art direction, integration review, provenance and release. Three bounded workers own closed chunk geometry/support, resolved-event integration/blood bursts, and independent native QA/capture.

Reuse approved native gore textures as faces on closed code-authored meshes. Staff head, coat, armor and limb regions come from their existing sprite sources. No new raster generation, image edits, audio or music work is part of this pass. Track exact source regions and preserve original PNG hashes.

Normal deaths retain their existing persistent corpse and create blood feedback without severing intact limbs. Authoritative overkill or later corpse-gib events release thicker tumbling chunks. Blood alone uses conforming flat patches. Small flesh pieces, limbs and hardware remain cosmetic: no gameplay colliders, damage, kills or progression changes.

Use shared physical world geometry for swept flight, bounce and supported settlement. Pieces may have varied resting angles but must not float, bridge stairs or embed through risers. Unsupported pieces keep falling and expire under a bounded lifetime; do not fabricate invisible support.

Make pistol, shotgun, Twin, Rivet, Siege and melee feedback explicit; heavier ruptures throw more directional blood. Armor contacts retain sparks. Bound flying particles, ground stains and settled chunks. Pause freezes effects and Retry clears them; duplicate death/corpse-gib callbacks must not create repeated effects.

First visual review is actual Intake combat with side and low-angle inspection of settled remains. Generic effects support existing chapter anatomy. Keep existing maps, movement, weapon balance, enemy attacks, lighting, HUD and accepted gunshots/music unchanged. Original music for every level stays deferred.
