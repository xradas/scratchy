# Pale Ward gore verification

Controlled actual source kills and native 30/60/120 rendering-cap tests cover persistent pools/corpses, heavy shotgun dismemberment, once-only death, armor sparks, world geometry/stair surfaces, pause and retry. Integrated normal AI/ammo route completes without secret supplies; actual Movie Maker video retains the stereo game mix. Prompts/source hashes: concepts/gore-art-v1.

The final exported executable is source commit 999ef7f321c80eba6b848d66185b5a81d2e4a00c. Native release smoke from /tmp explicitly executes the shot and condition checks. Godot release templates omit assert expressions; the first test used assert(try_fire()) and was therefore invalid, corrected before packaging. Final export-outside.log and export-gore.png show the real accepted shot, one kill, one shell consumed, nine settled parts, and a fresh retry. Current BUILD.json/SHA256SUMS describe the corrected binary.

Automated completion/captures are not human visual/listening approval, sustained release acceptance or a 5–8 minute human duration claim.
