# Source provenance

The existing local source READMEs and `public/audio-sources/cc0/LICENSE` were read before production. The latter is an Unlicense public-domain dedication for the older metal/steel/cracker set; **none of that set is used in this audition**.

The firearm source README identifies PPQ pistol and Mossberg shotgun takes as CC0/public-domain recordings from [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), distributed through [FPS Asset Kit](https://github.com/petroulacl/fps-asset-kit). This packet relies on that retained local provenance statement; it does not claim to have independently traced every upstream recording contributor's rights.

Inputs: ppq-pistol.wav, ppq-pistol-b.wav, ppq-pistol-c.wav, mossberg-shotgun.wav, mossberg-shotgun-b.wav, mossberg-shotgun-c.wav under `public/audio-sources/free-firearm-library/`. Exact SHA-256, selected onset region, source path and source URL are in `manifest.json`. Sources are converted from their native rate, high-passed, manually specified exponential tail-shaping applied after automated onset selection, and mixed with newly authored wood/cavity/coarse noise gestures. No re-use of the rejected old weapon render is involved.

New creature/world/counterweight layers contain only original deterministic mathematical excitation and processing. They contain no library foley or proprietary audio. Authors: Eyesore production agent, 3 October 2026. Performer: none; these are explicitly procedural candidates. Processing recipe, seed, dependencies and output hashes are retained. Production makes no statement about statutory rights for purely generated material; all code/recipes are retained for project use.
