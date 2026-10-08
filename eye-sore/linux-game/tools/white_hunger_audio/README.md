# White Hunger candidate renderer

Offline production, not game build/test/integration. Only writes `public/audio-prototypes/white-hunger/`; existing runtime files untouched.

Use Python compatible with pinned requirements, NumPy/SciPy and FFmpeg:

```bash
python -m venv /tmp/white-hunger-audio
/tmp/white-hunger-audio/bin/pip install -r linux-game/tools/white_hunger_audio/requirements.txt
/tmp/white-hunger-audio/bin/python linux-game/tools/white_hunger_audio/build_candidates.py
```

Script consumes six local CC0 firearm takes and synthesizes all other sources with fixed seed 91327. Measurements are produced from quantized output; no audio playback or game tests. Source metadata chunk warnings from SciPy indicate extra WAV chunks skipped, not audio data failure. Full provenance, onset/event map and listening limitations are in the output README/manifest.
