#!/usr/bin/env python3
"""Build a standalone review from unchanged reference/art/audio and native captures.
Only byte copies are made. No raster/audio rendering or source mutations occur.
Run again after replacement native capture reports are complete.
"""
from pathlib import Path
from html import escape
from html.parser import HTMLParser
from urllib.parse import urljoin, urlsplit, unquote
from urllib.request import urlopen
from urllib.error import URLError
import argparse, hashlib, json, shutil, struct

ROOT = Path(__file__).resolve().parents[1]
CONCEPTS = ROOT / 'concepts'
DEST = CONCEPTS / 'arsenal-architecture-v2/review'
PAGE = CONCEPTS / 'arsenal-ambush-review.html'
PREFIX = 'arsenal-architecture-v2/review/'
STAGES = {
    'pale_ward': ('The Pale Ward', 'Corrupted biotech', 'corrupted-biotech', '#b7cba0'),
    'ash_citadel': ('The Ash Citadel', 'Occult fortress', 'occult-fortress', '#d2a784'),
    'occupied_line': ('The Occupied Line', 'Invaded civic megastructure', 'civic-invasion', '#9fbccc'),
}
GUNS = {
    'twin_shotgun': ('4', 'Twin Shotgun', '16 pellets × 18 damage · two shells · 1.2 s cooldown', 'A broad double discharge for close groups and heavy single targets.'),
    'rivet_cannon': ('5', 'Rivet Cannon', '36 damage · centered hitscan · 0.16 s cooldown · rivet ammo', 'Rapid, dry ballistic pressure with a short, readable firing cycle.'),
    'siege_launcher': ('6', 'Siege Launcher', 'Physical rocket · 120 direct + up to 90 radial · rocket ammo', 'A swept projectile at 26 units/s, with a 4.8-unit blast radius. Walls and moving doors block splash; firing close to yourself carries blast risk.'),
}
SELECTED = [
    ('entry', 'Stage entry'),
    ('arena_one-trap-before', 'Physical bait before collection'),
    ('arena_one-bait-acquired', 'Bait acquired'),
    ('arena_one-trap-after', 'Closets open, entrance sealed'),
    ('elevation-arena_one_gallery', 'Raised combat gallery'),
    ('elevation-arena_two_altar', 'Raised altar / landing'),
]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def project_path(value): return ROOT / value.removeprefix('res://')
def load(path): return json.loads(path.read_text())
def pretty(value): return str(value).replace('_', ' ').title()
def local_url(relative): return PREFIX + str(relative)


class Builder:
    def __init__(self):
        self.media = []
        self.by_source = {}
        self.inputs = {}

    def copy(self, source, relative, role, expected=None):
        source = Path(source)
        digest = sha(source)
        if expected is not None and digest != expected:
            raise RuntimeError('Input hash mismatch; captures may be being replaced: ' + str(source))
        destination = DEST / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        if destination.read_bytes() != source.read_bytes() or sha(destination) != digest:
            raise RuntimeError('Byte copy failed: ' + str(destination))
        record = {'source': str(source.relative_to(ROOT)), 'copy': str(destination.relative_to(ROOT)), 'page_url': local_url(relative), 'role': role, 'sha256': digest, 'bytes': source.stat().st_size, 'source_byte_identical': True}
        if source.suffix.lower() == '.png':
            header = source.read_bytes()[:24]
            if header[:8] != b'\x89PNG\r\n\x1a\n': raise RuntimeError('Not a native PNG: ' + str(source))
            record['dimensions'] = list(struct.unpack('>II', header[16:24]))
        self.media.append(record)
        self.by_source[record['source']] = record
        return record['page_url']

    def evidence(self, source, relative): return self.copy(source, Path('evidence') / relative, 'unchanged evidence snapshot')


def image(url, label, caption, extra=''):
    return f'<figure><a class="image" href="{escape(url)}"><img src="{escape(url)}" alt="{escape(label)}" loading="lazy"></a><figcaption><strong>{escape(label)}</strong><span>{escape(caption)}</span>{extra}</figcaption></figure>'


def build():
    builder = Builder()
    reports = {}
    # Validate required report records and all selected image hashes before copying.
    for stage in STAGES:
        path = ROOT / f'verification/arsenal-architecture-v2/captures/{stage}-capture-state.json'
        report = load(path)
        if report['stage'] != stage or report['status'] != 'passed' or report['failures']:
            raise RuntimeError('Native capture report not ready: ' + str(path))
        by_label = {c['label']: c for c in report['captures']}
        required = [label for label, _ in SELECTED]
        if stage == 'pale_ward': required += [f'{gun}-{phase}' for gun in GUNS for phase in ['idle', 'fire', 'recover', 'switch']]
        for label in required:
            capture = by_label[label]
            for path_key, hash_key in [('full_window_png', 'full_window_sha256'), ('raw_main_subviewport_png', 'world_sha256')]:
                if sha(project_path(capture[path_key])) != capture[hash_key]:
                    raise RuntimeError('Native PNG/report mismatch: ' + stage + '/' + label)
        reports[stage] = (path, report, by_label)
    architecture_path = ROOT / 'assets/materials/architecture-v2/architecture.json'
    architecture = load(architecture_path)
    provenance = load(CONCEPTS / 'arsenal-architecture-v2/provenance.json')
    audio_base = CONCEPTS / 'audio-v6'; audio_manifest = load(audio_base / 'manifest.json')
    if len(audio_manifest['cues']) != 13: raise RuntimeError('Expected thirteen audio candidates')
    parts = [HEADER]
    report_links = {}
    summaries = []
    for stage, (name, theme, reference, accent) in STAGES.items():
        path, report, by_label = reports[stage]
        report_links[stage] = builder.evidence(path, path.name)
        reference_url = builder.copy(CONCEPTS / f'visual-v2/{reference}/scene_pixel_preview.png', Path('references') / f'{stage}-scene_pixel_preview.png', 'original static concept pixel preview; reference only')
        parts.append(f'<section class="stage" id="{stage}" style="--accent:{accent}"><div class="section-title"><p class="eyebrow">{escape(theme)}</p><h2>{escape(name)}</h2><p>Theme-specific enemies remain in their own stage. These scenes are reviewed independently; a later chapter transition remains separate work.</p></div>')
        parts.append('<div class="comparison">' + image(reference_url, 'Original concept reference', 'Unchanged scene_pixel_preview.png. Static artwork used only as the style reference.'))
        entry = by_label['entry']
        entry_url = builder.copy(project_path(entry['full_window_png']), Path('captures') / f'{stage}-entry.png', 'actual Main native window; controlled fixture', entry['full_window_sha256'])
        entry_world = builder.copy(project_path(entry['raw_main_subviewport_png']), Path('captures') / f'{stage}-entry-world.png', 'actual Main raw world SubViewport; controlled fixture', entry['world_sha256'])
        parts.append(image(entry_url, 'Actual Main: entry', 'Native window with HUD; controlled camera, frozen AI/player physics.', f'<a href="{entry_world}">Open raw world viewport</a>') + '</div>')
        parts.append('<p class="scope">Capture scope: actual Main rendering, controlled actor/camera teleport, frozen enemy AI and player physics, and a paused photograph. The bait snapshots use the normal physical collection method after teleporting onto the authored bait. They do not demonstrate an ordinary input-driven route or human style acceptance.</p><div class="views">')
        for label, title in SELECTED[1:]:
            capture = by_label[label]
            url = builder.copy(project_path(capture['full_window_png']), Path('captures') / f'{stage}-{label}.png', 'actual Main native window; controlled fixture', capture['full_window_sha256'])
            world = builder.copy(project_path(capture['raw_main_subviewport_png']), Path('captures') / f'{stage}-{label}-world.png', 'actual Main raw world SubViewport; controlled fixture', capture['world_sha256'])
            trap = capture.get('trap_state', {}).get('arena_one', {})
            summary = ' · '.join(f'{key.replace("_", " ")}: {str(trap[key]).lower()}' for key in ['triggered', 'latched', 'shutters_open', 'cleared'] if key in trap)
            extra = f'<a href="{world}">Raw world viewport</a>'
            if summary and 'elevation-' not in label: extra += f'<small>{escape(summary)}</small>'
            parts.append(image(url, title, capture['fixture'], extra))
        parts.append(f'</div><p class="evidence-link"><a href="{report_links[stage]}">Full native capture state · {len(report["captures"])} photographs</a></p></section>')
        summaries.append({'stage': stage, 'captures': len(report['captures']), 'scope': report['scope'], 'actual_main_scene': report['actual_main_scene'], 'report_sha256': sha(path), 'selected_labels': [label for label, _ in SELECTED]})
    parts.append('<section id="arsenal"><div class="section-title"><p class="eyebrow">Slots 4–6</p><h2>Three distinct heavy weapons</h2><p>Slots 1–3 retain pistol, shotgun and melee. New weapons are unavailable until a physical bait pickup grants ownership; ordinary reset clears the new inventory. Weapon images below are actual Main photographs of idle, accepted fire, recovery and switch phases in the Ward.</p></div>')
    ward = reports['pale_ward'][2]
    for gun, (key, name, stats, description) in GUNS.items():
        parts.append(f'<article class="gun" data-gun="{gun}"><header><span class="slot">{key}</span><div><h3>{name}</h3><p class="stats">{escape(stats)}</p><p>{escape(description)}</p></div></header><div class="phase-tabs" aria-label="{name} phase">')
        for phase in ['idle', 'fire', 'recover', 'switch']:
            parts.append(f'<button type="button" data-phase="{phase}" aria-pressed="{str(phase == "idle").lower()}">{pretty(phase)}</button>')
        parts.append('</div>')
        for phase in ['idle', 'fire', 'recover', 'switch']:
            capture = ward[f'{gun}-{phase}']
            if capture['weapon'] != gun or capture['phase'] != phase: raise RuntimeError('Weapon phase ownership mismatch')
            url = builder.copy(project_path(capture['full_window_png']), Path('weapons') / f'{gun}-{phase}.png', 'actual Main accepted weapon/presentation phase; controlled Ward fixture', capture['full_window_sha256'])
            world = builder.copy(project_path(capture['raw_main_subviewport_png']), Path('weapons') / f'{gun}-{phase}-world.png', 'actual Main raw world weapon phase; controlled Ward fixture', capture['world_sha256'])
            figure = image(url, f'{name}: {phase}', capture['fixture'], f'<a href="{world}">Raw world viewport</a><small>Source-region registration and camera projection do not establish exact illustrated bore alignment; human visual review remains pending.</small>')
            parts.append(f'<div class="phase" data-phase-view="{phase}"{ " hidden" if phase != "idle" else ""}>{figure}</div>')
        source = provenance['weapons'][gun]
        atlas_url = builder.copy(project_path(source['file']), Path('weapons') / f'{gun}-original-atlas.png', 'unchanged generated gun atlas source', source['sha256'])
        parts.append(f'<details><summary>Unchanged source atlas</summary>{image(atlas_url, name + " source atlas", "Native generated PNG copied byte-for-byte; authored regions select the phases without repainting this image.")}</details></article>')
    parts.append('</section>')
    parts.append('<section id="materials"><div class="section-title"><p class="eyebrow">Twelve material categories per theme</p><h2>Architecture source atlases</h2><p>Each theme has its own unchanged 1536 × 1024 atlas. The twelve authored regions provide wall, floor, ceiling, trim, grate, door, panel, damaged, stairs, infestation, banner and pillar surfaces. These are full original atlas images, not reconstructed swatches; the scene photographs above show their actual use.</p></div><div class="atlas-grid">')
    for stage, data in architecture['stages'].items():
        if len(data['regions']) != 12: raise RuntimeError('Expected twelve material categories per stage')
        source = project_path(data['file'])
        if Path(data['generated_original']).is_file() and Path(data['generated_original']).read_bytes() != source.read_bytes():
            raise RuntimeError('Material differs from its generated original: ' + stage)
        url = builder.copy(source, Path('materials') / f'{stage}-original-atlas.png', 'unchanged generated material atlas source; twelve authored regions', data['sha256'])
        cells = ''.join(f'<li><strong>{escape(pretty(name))}</strong><small>{escape(str(rect))}</small></li>' for name, rect in data['regions'].items())
        parts.append(f'<article>{image(url, STAGES[stage][0], "Full original atlas bytes; no crop, repaint or resampling was saved.")}<details><summary>12 native source regions</summary><ol class="regions">{cells}</ol></details></article>')
    parts.append('</div></section>')
    parts.append('<section id="sound"><div class="section-title"><p class="eyebrow">Thirteen dry candidates</p><h2>Recorded-source arsenal audio</h2><p>Compare at a comfortable level, starting low. Playback is manual; one player runs at a time. Each A/B file plays the dry excerpt mixture, 0.4 seconds of silence, then the designed cue. Source excerpts are separate from dry mixtures and designed outputs.</p><p>The nine existing CC0 source originals remain unchanged. No wet or squelch layer, previous processed cue, game audio, new download or synthesized oscillator is an input. All prior 35 runtime cues and stereo music bytes remain preserved. Listening acceptance is pending.</p></div>')
    audio_manifest_url = builder.evidence(audio_base / 'manifest.json', 'audio-v6-manifest.json')
    sources = {source['id']: source for source in audio_manifest['sources']}
    ordered = [gun + '_fire' for gun in GUNS] + ['siege_explosion'] + [gun + '_' + material for gun in GUNS for material in ['flesh', 'armor', 'hard']]
    for key in ordered:
        cue = audio_manifest['cues'][key]
        parts.append(f'<details class="audio-cue"{ " open" if key.endswith("_fire") or key == "siege_explosion" else ""}><summary>{escape(pretty(key))}<small>{cue["ogg_technical"]["seconds"]:.2f} s · decoded peak {cue["ogg_technical"]["peak_dbfs"]:.2f} dBFS</small></summary><p>{escape(cue["description"])}</p><div class="audio-grid">')
        for file_key, hash_key, title, role in [
            ('dry_file', 'dry_sha256', 'Dry excerpt mixture', 'dry source-excerpt mixture; no pitch/EQ'),
            ('file', 'sha256', 'Designed cue', 'designed dry arsenal candidate'),
            ('audition_file', 'audition_sha256', 'Dry → designed A/B', 'dry then designed audition; 0.4 s silent gap')]:
            source = audio_base / cue[file_key]
            url = builder.copy(source, Path('audio') / source.name.replace('.wav', '-' + file_key + '.wav'), role, cue[hash_key])
            parts.append(f'<label>{title}<audio controls preload="none" src="{url}"></audio><a href="{url}">Open WAV</a></label>')
        parts.append('</div><details class="source-edits"><summary>Original excerpts, source credits and edits</summary>')
        for index, edit in enumerate(cue['edits']):
            source = audio_base / edit['source_excerpt']
            url = builder.copy(source, Path('audio/excerpts') / source.name, 'original archival-recording excerpt at native source rate/channel count', edit['source_excerpt_sha256'])
            credit = sources[edit['source_id']]
            parts.append(f'<div class="excerpt"><p><strong>Layer {index + 1}: {escape(credit["id"])}</strong> · {escape(credit["creator"])} · <a href="{escape(credit["source_url"])}">Source page</a> · <a href="{escape(credit["license_url"])}">{escape(credit["license"])}</a></p><audio controls preload="none" src="{url}"></audio><p class="mono">Excerpt {edit["excerpt_start_seconds"]:.3f} s + {edit["excerpt_duration_seconds"]:.3f} s · pitch {edit["pitch_playback_ratio"]} · delay {edit["delay_seconds"]:.3f} s · layer gain {edit["layer_gain"]}</p><p class="filter">{escape(edit["filter_chain"])}</p></div>')
        parts.append('</details></details>')
    parts.append(f'<p class="evidence-link"><a href="{audio_manifest_url}">Full audio source/edit/hash manifest</a></p></section>')
    parts.append('<section id="evidence"><div class="section-title"><p class="eyebrow">Separate evidence scopes</p><h2>What was checked</h2><p>Physical bait grants its weapon, opens closet shutters and seals the room entrance. Clear restores the entrance; safety checks prevent moving shutters/entrances from trapping actors. The screenshots freeze these authored mechanisms for inspection. Ordinary route checks are separate from those photographs.</p></div><div class="proof-grid">')
    route_summaries = []
    for stage, (name, _, _, _) in STAGES.items():
        path = ROOT / f'verification/arsenal-architecture-v2/heavy-routes/{stage}-playtest.json'
        if not path.is_file():
            parts.append(f'<article><h3>{name}</h3><p>Fresh normal-inventory route evidence pending.</p></article>'); continue
        route = load(path); url = builder.evidence(path, 'source-stage-' + path.name)
        scope = 'Actual Main automated route' if route.get('main_integration') else 'Source-stage automated route harness'
        traps = route.get('traps', {})
        cleared = sum(bool(v.get('cleared')) and not bool(v.get('latched')) for v in traps.values())
        parts.append(f'<article><p class="eyebrow">{scope}</p><h3>{name}</h3><p>Completed: {str(route["completed"]).lower()} · {route["kills"]}/{route["total"]} kills · {cleared}/{len(traps)} traps clear/restored · {route.get("shortcuts", 0)} shortcuts.</p><p>{escape(route["scope"])}</p><p class="scope">Automated aim/strafe with real CharacterBody/AI physics and normal inventory. No teleport or secret supplies. Bot time does not establish human pacing. Main integration: {str(route.get("main_integration", False)).lower()}.</p><a href="{url}">Open exact route report</a></article>')
        route_summaries.append({'stage': stage, 'completed': route['completed'], 'main_integration': route.get('main_integration', False), 'scope': route['scope'], 'source': str(path.relative_to(ROOT)), 'sha256': sha(path)})
    parts.append('</div><p class="scope">Exact style match, illustrated weapon bore alignment, subjective listening and ordinary human play acceptance remain pending. Native captures and automated tests do not substitute for that review.</p>')
    for filename, title in [('audio-runtime.json', 'Actual audio ownership/routing'), ('aim/aim-balance.json', 'Native camera/aim regression')]:
        path = ROOT / 'verification/arsenal-architecture-v2' / filename
        if path.is_file():
            url = builder.evidence(path, Path(filename).name)
            parts.append(f'<p><a href="{url}">{title}</a></p>')
    prov_url = builder.evidence(CONCEPTS / 'arsenal-architecture-v2/provenance.json', 'art-provenance.json')
    arch_url = builder.evidence(architecture_path, 'architecture-regions.json')
    parts.append(f'<p><a href="{prov_url}">Art provenance</a> · <a href="{arch_url}">Material region metadata</a> · <a href="{PREFIX}manifest.json">Review byte-copy manifest</a></p></section>' + FOOTER)
    PAGE.write_text(''.join(parts))
    manifest = {'schema_version': 1, 'review': str(PAGE.relative_to(ROOT)), 'review_sha256': sha(PAGE), 'build_script': str(Path(__file__).relative_to(ROOT)), 'build_script_sha256': sha(Path(__file__)), 'transformation': 'All media are byte copies. HTML/CSS display sizing only; no saved image/audio raster/processing edits.', 'capture_set': 'final current native capture set', 'coordinator_integration_visual_review': {'status': 'Selected native views reviewed by coordinator', 'scope': 'Ward court/gallery and new guns; Citadel clerestory; Occupied Line crossing', 'full_scene_user_style_acceptance': 'pending'}, 'acceptance': 'Full scene human style, precise illustrated bore, sound and ordinary human play acceptance pending. HTTP/hash checks are not browser/UI review.', 'native_capture_reports': summaries, 'route_reports': route_summaries, 'audio_source_manifest_sha256': sha(audio_base / 'manifest.json'), 'media': builder.media}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'ARSENAL_REVIEW_BUILT: {len(builder.media)} byte-verified media/evidence copies; 3 references, 18 stage views, 12 Ward gun phases, 3 unchanged twelve-region atlases, 13 audio candidates. Human review pending.')


HEADER = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eyesore · Arsenal & ambush review</title><style>
:root{color-scheme:dark;--bg:#121413;--panel:#1a1d1b;--line:#353d36;--text:#e8ebe5;--muted:#aab5a8;--accent:#becfac}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.6 system-ui,sans-serif}a{color:#d6e6c4;text-underline-offset:4px}button,a{touch-action:manipulation}button:focus-visible,a:focus-visible,summary:focus-visible{outline:2px solid #e4eec7;outline-offset:4px}nav{display:flex;gap:24px;flex-wrap:wrap;border-bottom:1px solid var(--line);padding:20px max(24px,calc((100vw - 1320px)/2));background:#121413;position:sticky;top:0;z-index:5}nav a{font-size:13px;font-weight:650;text-decoration:none}main{max-width:1320px;margin:auto;padding:0 24px}h1{font-size:clamp(36px,5vw,68px);line-height:1.06;letter-spacing:-.05em;max-width:1000px;font-weight:650;margin:20px 0}h2{font-size:36px;line-height:1.2;letter-spacing:-.035em;margin:4px 0 20px}h3{font-size:23px;margin:0 0 8px}p{margin:10px 0 18px}.hero{padding:70px 0 48px}.hero>p{max-width:860px}.eyebrow{font-size:12px;text-transform:uppercase;letter-spacing:.14em;font-weight:750;color:var(--accent);margin:0 0 12px}.chips{display:flex;gap:10px;flex-wrap:wrap;margin-top:26px}.chips span{border:1px solid var(--line);padding:6px 11px;font-size:12px;border-radius:3px;color:var(--muted)}section{padding:50px 0;border-top:1px solid var(--line);scroll-margin-top:80px}.section-title{max-width:1000px;margin-bottom:30px}.comparison{display:grid;grid-template-columns:1fr 1fr;gap:20px}.views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;margin-top:28px}figure{margin:0;background:var(--panel);border:1px solid var(--line);height:100%}.image{display:block;background:#0b0d0b}img{display:block;width:100%;height:auto;image-rendering:pixelated}figcaption{padding:16px;font-size:13px;line-height:1.55}figcaption strong,figcaption span,figcaption a,figcaption small{display:block}figcaption strong{font-size:16px;color:var(--accent);margin-bottom:6px}figcaption span,figcaption small{color:var(--muted)}figcaption a{margin-top:9px}figcaption small{margin-top:8px;font-size:11px}.scope{color:var(--muted);font-size:13px;line-height:1.6;max-width:1100px;margin-top:22px}.evidence-link{font-size:13px;margin-top:22px}.gun{margin:30px 0 50px;max-width:1050px}.gun header{display:flex;gap:18px;align-items:flex-start;margin-bottom:22px}.slot{font-size:28px;color:var(--accent);border:1px solid var(--line);width:50px;text-align:center;flex-shrink:0}.stats{font-size:14px;color:var(--accent)}.phase-tabs{display:flex;gap:8px;margin-bottom:12px}.phase-tabs button{background:var(--panel);color:var(--muted);border:1px solid var(--line);padding:9px 20px;font:inherit;font-size:13px;cursor:pointer}.phase-tabs button[aria-pressed=true]{background:#34402e;color:#eff6e9;border-color:#78916d}[hidden]{display:none!important}details{margin-top:18px}summary{cursor:pointer;color:#d4dfca;font-size:14px;padding:12px 0}details .image{margin-top:12px}.atlas-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.regions{padding:12px 22px;background:var(--panel);font-size:12px;list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:12px}.regions strong,.regions small{display:block}.regions small{color:var(--muted);font:10px/1.4 ui-monospace,monospace}.audio-cue{border:1px solid var(--line);padding:6px 20px 14px;background:var(--panel)}.audio-cue>summary{font-weight:650;font-size:17px}.audio-cue>summary small{font-weight:400;color:var(--muted);margin-left:16px;font-size:12px}.audio-cue>p{font-size:13px;color:var(--muted)}.audio-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.audio-grid label{font-size:13px}audio{display:block;width:100%;max-width:430px;margin:10px 0}.audio-grid a{font-size:12px}.excerpt{padding:15px 0;border-top:1px solid var(--line)}.excerpt p{font-size:12px}.mono,.filter{font-family:ui-monospace,monospace;color:var(--muted);overflow-wrap:anywhere}.proof-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}.proof-grid article{border:1px solid var(--line);padding:22px;background:var(--panel)}.proof-grid p{font-size:13px}.proof-grid a{font-size:13px}footer{padding:35px 0 70px;color:var(--muted);font-size:12px}@media(max-width:850px){.atlas-grid,.proof-grid{grid-template-columns:1fr}.audio-grid{grid-template-columns:1fr}.comparison,.views{grid-template-columns:1fr}.hero{padding-top:42px}h2{font-size:28px}nav{gap:17px;padding:15px 24px}.audio-cue>summary small{display:block;margin-left:0}.phase-tabs button{padding:9px 13px}main{padding:0 18px}}
</style></head><body><nav aria-label="Review sections"><a href="#spaces">Spaces</a><a href="#arsenal">Arsenal</a><a href="#materials">Materials</a><a href="#sound">Audio</a><a href="#evidence">Evidence</a></nav><main><header class="hero" id="spaces"><p class="eyebrow">Eyesore · production review</p><h1>Heavy weapons.<br>Physical bait. Layered rooms.</h1><p>Three separate themes, three new weapon roles, and room traps that respond to authored pickups. Compare the original static references with native game photographs, inspect the unchanged atlases, then audition the new dry recorded-source cues.</p><div class="chips"><span>3 themes</span><span>Slots 4–6</span><span>12 materials per theme</span><span>13 new audio cues</span><span>Final native capture set</span><span>User acceptance pending</span></div><p class="scope">Actual game images here are controlled Main capture fixtures. Reference artwork stays labeled separately. Selected native integration views have been reviewed by the coordinator; full-scene user style acceptance remains pending. All media bytes are copied unchanged; CSS display sizing does not change the source files.</p></header>'''
FOOTER = '''<footer>Native source bytes and technical checks support review. Human visual, listening and ordinary play acceptance remain pending. Earlier review pages remain untouched.</footer></main><script>
for(const gun of document.querySelectorAll('.gun')){for(const button of gun.querySelectorAll('[data-phase]')){button.addEventListener('click',()=>{for(const tab of gun.querySelectorAll('[data-phase]'))tab.setAttribute('aria-pressed',String(tab===button));for(const view of gun.querySelectorAll('[data-phase-view]'))view.hidden=view.dataset.phaseView!==button.dataset.phase;});}}
const players=[...document.querySelectorAll('audio')];for(const player of players){player.volume=.45;player.addEventListener('play',()=>{for(const other of players)if(other!==player)other.pause();});}
</script></body></html>'''


class AssetParser(HTMLParser):
    def __init__(self): super().__init__(); self.urls = set(); self.autoplay = False
    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if 'autoplay' in values: self.autoplay = True
        for key in ['src', 'href', 'poster']:
            value = values.get(key, '')
            if value and not value.startswith('#') and not urlsplit(value).scheme:
                self.urls.add(value)


def verify(check_http=False):
    manifest = load(DEST / 'manifest.json')
    if sha(PAGE) != manifest['review_sha256']: raise RuntimeError('Review page changed after manifest')
    for media in manifest['media']:
        if sha(ROOT / media['source']) != media['sha256'] or sha(ROOT / media['copy']) != media['sha256']:
            raise RuntimeError('Media byte hash changed: ' + media['copy'])
    parser = AssetParser(); parser.feed(PAGE.read_text())
    if parser.autoplay: raise RuntimeError('Autoplay is forbidden')
    urls = sorted(parser.urls)
    for url in urls:
        path = (CONCEPTS / unquote(urlsplit(url).path)).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file(): raise RuntimeError('Missing local page URL: ' + url)
    result = {'review': str(PAGE.relative_to(ROOT)), 'review_sha256': sha(PAGE), 'byte_verified_media': len(manifest['media']), 'local_page_asset_urls': len(urls), 'autoplay': False, 'browser_ui_review': 'not performed by this tool', 'human_acceptance': 'pending', 'http': []}
    if check_http:
        base = None
        for candidate in ['http://127.0.0.1:8765/arsenal-ambush-review.html', 'http://127.0.0.1:8765/concepts/arsenal-ambush-review.html']:
            try:
                with urlopen(candidate, timeout=15) as response: body = response.read()
            except URLError: continue
            if hashlib.sha256(body).hexdigest() == sha(PAGE): base = candidate; break
        if base is None: raise RuntimeError('Localhost8765 does not serve the current review page from concepts or project root')
        result['page_url'] = base
        for url in [''] + urls:
            target = urljoin(base, url)
            expected_path = PAGE if not url else (CONCEPTS / unquote(urlsplit(url).path)).resolve()
            with urlopen(target, timeout=15) as response:
                body = response.read(); status = response.status
            if status != 200 or hashlib.sha256(body).hexdigest() != sha(expected_path):
                raise RuntimeError('HTTP bytes/status differ: ' + target)
            result['http'].append({'url': target, 'status': status, 'sha256': hashlib.sha256(body).hexdigest(), 'bytes': len(body)})
    evidence = ROOT / 'verification/arsenal-architecture-v2/review-http.json'
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps(result, indent=2) + '\n')
    print(f'ARSENAL_REVIEW_VERIFY_OK: {len(manifest["media"])} unchanged copies; {len(urls)} local asset URLs; HTTP checks {len(result["http"])}; no autoplay. Browser/UI and human review not claimed.')


if __name__ == '__main__':
    args = argparse.ArgumentParser(); args.add_argument('--verify-only', action='store_true'); args.add_argument('--check-http', action='store_true'); options = args.parse_args()
    if not options.verify_only: build()
    verify(options.check_http)
