#!/usr/bin/env python3
"""Build a file://-compatible concept review; no dependencies or network requests."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parent
visual = json.loads((ROOT / 'visual-v2/manifest.json').read_text())
audio = json.loads((ROOT / 'audio/manifest.json').read_text())
identities = {'corrupted-biotech':'biotech', 'occult-fortress':'fortress', 'civic-invasion':'civic'}
tracks = {'biotech':('Abelian','abelian'), 'fortress':('Dragged Through Hellfire','dragged-through-hellfire'), 'civic':('The Recon Mission','the-recon-mission')}

def image(path, alt, cls=''):
    assert (ROOT / 'visual-v2' / path).is_file(), path
    return f'<img class="{cls}" src="visual-v2/{escape(path)}" alt="{escape(alt)}">'

def player(path, label):
    assert (ROOT / 'audio' / path).is_file(), path
    return f'<audio controls preload="auto" aria-label="{escape(label)}" src="audio/{escape(path)}"></audio>'

choices, packets, comparisons = [], [], []
for concept in visual['concepts']:
    slug = concept['slug']; kind = identities[slug]
    title = concept['title'].split(' / ', 1)[-1].title()
    choices.append(f'<button type="button" class="choice" data-packet="{slug}" aria-pressed="false" aria-controls="{slug}">{image(concept["scene_pixel_preview"],concept["subtitle"])}<span class="name">{escape(title)}</span><span class="description">{escape(concept["subtitle"])}</span></button>')
    swatches = ''.join(f'<div class="swatch" title="{escape(color["name"])}"><span style="background:{color["hex"]}"></span><small>{color["hex"]}</small></div>' for color in concept['palette'])
    music, source = tracks[kind]
    sources = f'<a href="https://opengameart.org/content/{source}">{escape(music)}</a>'
    packets.append(f'''<section class="packet" id="{slug}" data-accent="{ {'biotech':'#bde48e','fortress':'#e9b080','civic':'#5beaf1'}[kind] }" hidden>
    <div class="heading"><div><h2>{escape(title)}</h2><p class="muted">{escape(concept['subtitle'])} · {escape(concept['tag'])}</p></div><a href="visual-v2/{concept['board']}">Open full art board ↗</a></div>
    <div class="columns"><div>{image(concept['scene_pixel_preview'],'Static first-person combat composition for '+concept['subtitle'],'scene')}<p class="hint">320×180 scale test, enlarged 2× to 640×360 · generated static artwork</p><div class="swatches">{swatches}</div><div class="copy"><h3>Reading the fight</h3><p>{escape(concept['read'])}</p><h3>Production considerations</h3><p class="muted">{escape(concept['cost'])}</p></div></div>
    <div><div class="audio-block"><h3>Music · 25 seconds</h3><div class="hint">{sources} — Zander Noriega</div>{player(f'cues/{kind}_music_25s.wav',title+' music audition')}</div>
    <div class="audio-block"><h3>Recorded guns and impacts · 10 seconds</h3><div class="hint">Shots, contact, then the same warning at 8.2 / 8.9 s.</div>{player(f'cues/{kind}_sfx_10s.wav',title+' sound audition')}</div>
    <div class="audio-block"><h3>Music with warnings · 25 seconds</h3><div class="hint">Can you hear both warnings at 16.2 / 16.9 s?</div>{player(f'cues/{kind}_masking_check_25s.wav',title+' warning masking audition')}</div>
    <p class="hint">Compare at the same device volume. These are sourced and edited auditions. You liked the music. Sound effects and actual game mixing still need listening review.</p>
    <h3>Open question</h3><p class="muted">{escape(concept['limitation'])}</p></div></div>
    <details><summary>Palette, materials, enemy / gun designs and HUD thumbnail</summary>{image(concept['board'],concept['subtitle']+' full equally scoped concept packet','board')}</details></section>''')
    comparisons.append(f'<tr><th scope="row">{escape(title)}</th><td>{escape(concept["read"])}</td><td>{escape(concept["cost"])}</td><td>{escape(music)}<br><span class="hint">Music praised by you; final gameplay mix still pending.</span></td></tr>')

page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Eyesore build two — identity review</title><link rel="stylesheet" href="review.css"><script defer src="review.js"></script></head><body><main>
<header><div class="eyebrow">EYESORE / BUILD TWO / IDENTITY REVIEW</div><h1>Rebuilt visual directions.</h1><p class="muted">Revised after your feedback: textured room depth, solid weapon forms and stronger creature anatomy, guided by classic Doom. The music is retained.</p><p class="hint">Browse each packet below. Reply in chat with your choice or requested revisions; browsing does not commit a selection.</p></header>
<nav class="choices" aria-label="Concept packets">{''.join(choices)}</nav>{''.join(packets)}
<details><summary>Actual Godot 3D room preview</summary><p class="muted">Connected spaces, thick doorway, walkable raised service platform, pipes and machinery, original pixel materials and cast shadows. These are actual Godot captures. Production enemy and weapon sprites are still pending.</p><img class="board" src="engine-preview/main.png" alt="Actual Godot 3D main room preview"><img class="board" src="engine-preview/annex.png" alt="Actual connected Godot annex preview"></details><section class="shared"><div><h3>Same recording: dry, then designed</h3><p class="muted">Three pistol shots at 0–6 s, repeated with body EQ and short reflections at 6–12 s. The recording is peak matched for comparison.</p>{player('cues/shared_guns_dry_vs_edited_12s.wav','Shared dry then designed gunshot comparison')}</div><div><h3>Next step after your selection</h3><p class="muted">Build the complete pistol / seven-pellet shotgun / melee exchange with two enemies in a calibration room. Review movement, firing, animation, impact and actual game audio together before expanding the level.</p></div></section>
<details><summary>Compare all three directions</summary><table class="compare"><thead><tr><th>Direction</th><th>Readability / identity</th><th>Production considerations</th><th>Music audition</th></tr></thead><tbody>{''.join(comparisons)}</tbody></table></details>
<footer class="credits"><p>Visual revision: built-in imagegen concept studies with recorded prompts and untouched source boards. Each direction includes a combat composition, two creature designs, pistol/shotgun studies, four material samples, palette and HUD study. These are generated design studies; complete hand-authored pixel sprite sets remain pending. Additional poses in some boards are illustrative, not completed animation sets.</p><p>Music by <a href="https://opengameart.org/users/zander-noriega">Zander Noriega</a>, <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>. Edits: excerpts, fades, gain, format conversion and audition mixes. Firearms: Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney; impacts: Ben Jaszczak and Brian Nelson; warning: Kenney. SFX are CC0. <a href="audio/README.md">Full credits / edit notes</a> · <a href="audio/manifest.json">Audio provenance</a> · <a href="visual-v2/manifest.json">Concept prompts / provenance</a>.</p><p>The revised volume, anatomy and spatial direction is ready for your review. Full animation sets and complete combat production follow your identity selection.</p></footer>
</main></body></html>'''
(ROOT / 'index.html').write_text(page)
print('Built portable concept review:', ROOT / 'index.html')
