# Pale Ward shotgun security troop (v22)

Pistol security remains the ordinary infected guard. A separate `infected_security_shotgun` resource and art entry defines the pump-shotgun troop. One is placed in each of Ward Intake (triage), Containment (isolation A), and Breach Circuit (crossfire). Each has a stable authored ID, a visible carried shotgun, the matching seven-pellet attack and fire cue, and a persistent three-shell weapon/ammo drop. The troop has a 0.72-second windup, 0.7-second recovery, and 10-metre attack range; pistol guards retain their own timing and appearance.

Both security types use the infected-soldier detection, pain, and death voice family. The shotgun troop has its own directional atlas, front attack strip, and gore parts. Campaign entry still provides only the pistol and melee fallback. The first triage troop is the early shotgun source.

Godot import, the focused enemy weapon/drop fixture, Ward geometry/supply checks, the legacy pistol-security combat fixture, native gore/foundation smoke, and the physical three-level Ward and connected nine-level campaign routes pass. The Ward route exits the three levels with 43.06, 68.26, and 66.2 health. Human review should assess how clearly the troop reads at combat distance and whether its windup is fair under music.
