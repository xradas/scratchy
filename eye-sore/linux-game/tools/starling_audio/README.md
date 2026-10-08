# Starling audio candidate renderer

Offline production only; writes the isolated prototype folder. Requires FFmpeg and pinned NumPy/SciPy:

```bash
python -m venv /tmp/starling-audio
/tmp/starling-audio/bin/pip install -r linux-game/tools/starling_audio/requirements.txt
/tmp/starling-audio/bin/python linux-game/tools/starling_audio/build_candidates.py
```

Seed 41791; detailed rendered output/provenance/listening instructions in `public/audio-prototypes/starling-last-lap/README.md` and manifest. Existing runtime banks/engine/Makefile are untouched. WAV extra metadata chunk warnings mean those ancillary chunks were skipped while reading PCM. All procedural cues clearly labeled; no game audio/tunes copied, no listener validation claimed.
