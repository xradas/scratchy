# Pale Ward environment and combat pass

All three Pale Ward campaign scenes are generated from `docs/level-redesign-v13/levels.json` by `tools/author_levels_v13.py`. The v19 environment helper adds one new polygonal room per level, angled wall masses, supported utility fittings, lower ambient light and selected damaged fixtures. Ward 03 opens the bridge onto a procedural sky and an animated toxic basin; a physical fall applies 25 damage and returns the player to the deck. The objective graph, door physics, and lift routes remain authored in the same source.

The supply author distributes the existing main-route budgets across distinct positions in each room. Health and armor boxes show +1, +25 or +50; ordinary pickup caps remain 100. A single optional overdrive pickup per Ward level adds up to 100 and caps at 200. Four melee positions per level become ranged guards, keeping the total actor count constant. Secret entrances now use wall-matched panels with small damaged seams instead of conspicuous lit door strips.

The infected scientist and guard have clearer planted walk steps. Security now has a dedicated front-facing aim and firing pose with a measured muzzle location. Each Pale Ward enemy type has its own detection cue; staff attack, hurt and death voices are distinct. Doors emit one spatial sound per accepted opening or closing transition. [Guard art notes](security-front-attack.md), [visual credits](../../assets/VISUAL_CREDITS.md), and [audio provenance](../../assets/audio/ward-v19/provenance.json) describe the new assets.

Reproducible checks:

- `tools/godot.sh --headless --editor --quit`
- `tools/godot.sh --headless --script tools/check_levels_geometry_v13.gd -- --level=pale_ward_01` (repeat for `02` and `03`)
- `tools/godot.sh --headless --script tools/check_ward_supplies_v19.gd`
- `tools/godot.sh --headless --script tools/check_ward_audio_v19.gd`
- `tools/godot.sh --headless --script tools/check_staff_v19.gd`

Actual Compatibility-renderer bridge frames are under `verification/ward-environment-v19/`. Automated room and combat probes do not establish human difficulty, visual fidelity to the original concepts, or listening appeal; those still need play review.

The final embedded Linux export was launched from `/tmp` with the ordinary campaign loadout. Its physical `--v13-route-test` completed all three Pale Ward levels with real combat and interactions, no secret supplies, and zero route failures. The [export receipt](../../verification/ward-environment-v19/export-route.json) records the exact segments, carries, kills and exit flags. This automated route is a structural and survivability proof, not a human pacing or balance verdict.
