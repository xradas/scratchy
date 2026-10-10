"""Original-source-only arsenal candidates from already preserved CC0 recordings.
No downloads, synthesized oscillators, rejected wet cues, game audio or prior
processed cues are inputs. Run with Python 3 and FFmpeg/FFprobe on PATH.
"""
from pathlib import Path
import array, copy, hashlib, json, math, shutil, subprocess, sys, tempfile

BASE = Path(__file__).resolve().parent
PROJECT = BASE.parents[1]
SOURCE_BASE = BASE.parent / 'audio-v3'
RATE = 48000
F = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-y']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ff(args):
    result = subprocess.run(F + list(map(str, args)), capture_output=True, text=True)
    if result.returncode: raise RuntimeError(result.stderr)


def stats(path):
    raw = subprocess.check_output(F + ['-i', str(path), '-ar', str(RATE), '-ac', '1', '-f', 'f32le', '-'], stderr=subprocess.DEVNULL)
    samples = array.array('f'); samples.frombytes(raw)
    peak = max(map(abs, samples), default=0)
    rms = math.sqrt(sum(v * v for v in samples) / max(1, len(samples)))
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=channels,sample_rate,codec_name', '-of', 'json', str(path)]))
    return {'seconds': len(samples) / RATE, 'peak': peak, 'peak_dbfs': 20 * math.log10(max(peak, 1e-12)), 'rms': rms, 'rms_dbfs': 20 * math.log10(max(rms, 1e-12)), 'rail_samples': sum(abs(v) >= 1 for v in samples), 'probe': probe}


def layer(source, start, duration, pitch=1, filters='', gain=1, delay=0):
    return dict(source_id=source, excerpt_start_seconds=start, excerpt_duration_seconds=duration,
                pitch_playback_ratio=pitch, filters=filters, layer_gain=gain, delay_seconds=delay)


L = layer
recipes = {
    'twin_shotgun_fire': (.65, -8, 'Two recorded shotgun discharges; broad crack and low body, separated by 22 ms.', [
        L('shotgun', .835, .65, .82, 'highpass=f=45,equalizer=f=100:t=q:w=.8:g=3,lowpass=f=8000'),
        L('shotgun', .835, .65, .95, 'highpass=f=110,lowpass=f=8500', .65, .022)]),
    'rivet_cannon_fire': (.16, -8, 'Short recorded pistol crack and quiet metal-object tick for rapid ballistic fire.', [
        L('pistol', .934, .16, .8, 'highpass=f=85,lowpass=f=7800'),
        L('click', 0, .08, 1.1, 'highpass=f=600,lowpass=f=6000', .12, .005)]),
    'siege_launcher_fire': (.45, -8, 'Low recorded shotgun thump with a dry metal clunk; lowpass at 2 kHz.', [
        L('shotgun', .835, .40, .62, 'highpass=f=35,lowpass=f=2000'),
        L('dry-metal_hit_03', 0, .25, .7, 'highpass=f=70,lowpass=f=2000', .28, .015)]),
    'siege_explosion': (.8, -10, 'Dry bass blast from lowered recorded shotgun, wood cracking and metal; no squelch or wet layers.', [
        L('shotgun', .835, .8, .48, 'highpass=f=28,equalizer=f=75:t=q:w=.8:g=4,lowpass=f=2600'),
        L('dry-wood_cracking_01', 0, .3, .8, 'highpass=f=100,lowpass=f=4200', .35, .015),
        L('dry-metal_hit_03', 0, .3, .62, 'highpass=f=45,lowpass=f=2600', .3, .025)])
}
profiles = {'twin_shotgun': (.35, .78, .012), 'rivet_cannon': (.12, 1.15, .004), 'siege_launcher': (.45, .62, .02)}
for weapon, (duration, pitch, delay) in profiles.items():
    source_duration = min(duration, .34)
    recipes[weapon + '_flesh'] = (duration, -14, 'Dry recorded punching-bag impact and restrained wood crack; aggregate contact only.', [
        L('dry-qubodupPunch02' if weapon == 'rivet_cannon' else 'dry-qubodupPunch01', 0, source_duration, pitch, 'highpass=f=65,equalizer=f=170:t=q:w=.8:g=2,lowpass=f=5000'),
        L('dry-wood_cracking_01', 0, min(.16, duration), pitch * 1.04, 'highpass=f=180,lowpass=f=4300', .16, delay)])
    recipes[weapon + '_armor'] = (duration, -14, 'Dry recorded metal strike with restrained hammer body; no wet foley.', [
        L('dry-metal_hit_01' if weapon == 'rivet_cannon' else 'dry-metal_hit_03', 0, source_duration, pitch, 'highpass=f=70,lowpass=f=6200'),
        L('dry-wood_hammer_01', 0, min(.2, duration), pitch * .95, 'highpass=f=75,lowpass=f=2600', .22, delay)])
    recipes[weapon + '_hard'] = (duration, -14, 'Dry wood hammer and cracking, with weapon-sized duration and body.', [
        L('dry-wood_hammer_01', 0, source_duration, pitch, 'highpass=f=80,lowpass=f=5500'),
        L('dry-wood_cracking_01', 0, min(.18, duration), pitch * 1.03, 'highpass=f=200,lowpass=f=6500', .28, delay)])


def main():
    for directory in ['cues', 'dry', 'source-excerpts', 'auditions', 'preservation']:
        (BASE / directory).mkdir(parents=True, exist_ok=True)
    runtime = PROJECT / 'assets/audio/arsenal-v2'; runtime.mkdir(parents=True, exist_ok=True)
    ledger_path = PROJECT / 'assets/audio/runtime-cues.json'
    ledger = json.loads(ledger_path.read_text())
    old_cues = {k: copy.deepcopy(v) for k, v in ledger['cues'].items() if k not in recipes}
    if len(old_cues) != 35:
        raise RuntimeError('Expected exactly 35 existing cues')
    preserved = BASE / 'preservation/runtime-before.json'
    if not preserved.exists():
        preserved.write_text(json.dumps({**ledger, 'cues': old_cues}, indent=2) + '\n')
        shutil.copy2(PROJECT / 'resources/combat_audio.tres', BASE / 'preservation/combat_audio-before.tres')
    baseline = json.loads(preserved.read_text())
    if old_cues != baseline['cues']:
        raise RuntimeError('Existing cue ledger changed; do not silently replace preservation baseline')
    old_files = {value['file']: sha(PROJECT / value['file'].removeprefix('res://')) for value in old_cues.values()}
    old_files[ledger['level_music']] = sha(PROJECT / ledger['level_music'].removeprefix('res://'))
    source_manifest = json.loads((SOURCE_BASE / 'manifest.json').read_text())
    used_ids = sorted({edit['source_id'] for _, _, _, edits in recipes.values() for edit in edits})
    sources = {s['id']: copy.deepcopy(s) for s in source_manifest['sources'] if s['id'] in used_ids}
    for source in sources.values():
        path = SOURCE_BASE / source['original']
        if sha(path) != source['original_sha256']:
            raise RuntimeError('Original source hash mismatch: ' + str(path))
        source['original'] = str(path.relative_to(PROJECT))
        source['license_evidence'] = ['concepts/audio-v3/' + p for p in source.get('license_evidence', [])]
        source['license_evidence_sha256'] = {'concepts/audio-v3/' + p: value for p, value in source.get('license_evidence_sha256', {}).items()}
    manifest = {'schema_version': 6, 'design': 'Thirteen dry original-source-only arsenal candidates. Preserved prepared-library recordings are archival source originals, not claims of unprocessed microphone takes. No new research/downloads, synthesis, processed-cue inputs, game audio, wet effects or music edits.',
                'approval_status': 'Technical candidates; subjective listening approval pending.',
                'source_manifest': 'concepts/audio-v3/manifest.json', 'sources': list(sources.values()), 'cues': {},
                'preservation': {'old_cue_count': 35, 'old_cue_metadata_unchanged': True, 'runtime_before': 'preservation/runtime-before.json', 'profile_before': 'preservation/combat_audio-before.tres', 'profile_before_sha256': sha(BASE / 'preservation/combat_audio-before.tres'), 'existing_audio_sha256': old_files},
                'mix_format': {'sample_rate': RATE, 'channels': 1, 'designed_wav_codec': 'pcm_s24le', 'ogg_codec': 'libvorbis', 'ogg_quality': 6},
                'runtime_routing': {'fire': 'Weapons/nonspatial', 'contacts': 'World/spatial', 'explosion': 'World/spatial, one ordnance_explosion per accepted shot identity'}}
    with tempfile.TemporaryDirectory(prefix='eyesore-arsenal-audio-') as temp_directory:
        temp = Path(temp_directory)
        for key, (duration, target, description, edits) in recipes.items():
            designed_layers, dry_layers, metadata = [], [], []
            for index, edit in enumerate(edits):
                source = sources[edit['source_id']]
                original = PROJECT / source['original']
                excerpt = BASE / 'source-excerpts' / f'{key}-layer-{index}.wav'
                ff(['-i', original, '-ss', edit['excerpt_start_seconds'], '-t', edit['excerpt_duration_seconds'], '-c:a', 'pcm_s24le', excerpt])
                raw = temp / f'raw-{index}.wav'
                ff(['-i', excerpt, '-ar', RATE, '-ac', 1, '-c:a', 'pcm_f32le', raw])
                raw_peak = stats(raw)['peak']
                raw_gain = (10 ** (-12 / 20)) / max(raw_peak, 1e-12)
                dry = temp / f'dry-{index}.wav'
                ff(['-i', raw, '-af', f'volume={raw_gain}', '-c:a', 'pcm_f32le', dry])
                designed = temp / f'fx-{index}.wav'
                chain = f'asetrate={RATE}*{edit["pitch_playback_ratio"]},aresample={RATE}'
                if edit['filters']: chain += ',' + edit['filters']
                # Explicit layer trim prevents pitched tails from obscuring rapid fire.
                layer_duration = max(.02, duration - edit['delay_seconds'])
                fade_out = min(.035, layer_duration * .20)
                chain += f',apad,atrim=duration={layer_duration},afade=t=in:d=0.002,afade=t=out:st={layer_duration-fade_out}:d={fade_out}'
                ff(['-i', raw, '-af', chain, '-c:a', 'pcm_f32le', designed])
                design_peak = stats(designed)['peak']
                design_gain = (10 ** (-12 / 20)) / max(design_peak, 1e-12)
                designed_layers.append((designed, edit['delay_seconds'], edit['layer_gain'] * design_gain))
                dry_layers.append((dry, edit['delay_seconds'], edit['layer_gain']))
                metadata.append({**edit, 'original': source['original'], 'original_sha256': source['original_sha256'], 'source_excerpt': str(excerpt.relative_to(BASE)), 'source_excerpt_sha256': sha(excerpt), 'source_excerpt_technical': stats(excerpt)['probe'], 'mono_resample_raw_peak': raw_peak, 'dry_peak_match_gain': raw_gain, 'designed_peak_match_gain': design_gain, 'filter_chain': chain, 'fade_in_seconds': .002, 'fade_out_seconds': fade_out})
            def mix(layers, output, dry_reference=False):
                args, graph = [], []
                for i, (path, delay, gain) in enumerate(layers):
                    args += ['-i', path]
                    graph.append(f'[{i}:a]volume={gain},adelay={round(delay*RATE)}S[e{i}]')
                # Dry references have no pitch/EQ/fades; selected sources, gain, placement and container duration only.
                graph.append(''.join(f'[e{i}]' for i in range(len(layers))) + f'amix=inputs={len(layers)}:normalize=0,apad,atrim=duration={duration}[mix]')
                ff(args + ['-filter_complex', ';'.join(graph), '-map', '[mix]', '-c:a', 'pcm_f32le', output])
                return ';'.join(graph)
            mixed = temp / 'mix.wav'; graph = mix(designed_layers, mixed)
            final_gain = (10 ** (target / 20)) / max(stats(mixed)['peak'], 1e-12)
            wav = BASE / 'cues' / (key + '.wav'); ogg = BASE / 'cues' / (key + '.ogg')
            # Lossy encoding may overshoot. Correct only the final export gain to enforce target bounds.
            for attempt in range(4):
                ff(['-i', mixed, '-af', f'volume={final_gain}', '-c:a', 'pcm_s24le', wav])
                ff(['-i', wav, '-c:a', 'libvorbis', '-q:a', 6, ogg])
                ogg_stats = stats(ogg)
                if ogg_stats['peak_dbfs'] <= target + .03: break
                final_gain *= 10 ** ((target - .02 - ogg_stats['peak_dbfs']) / 20)
            dry_mix = temp / 'dry-mix.wav'; dry_graph = mix(dry_layers, dry_mix, True)
            dry_gain = (10 ** (target / 20)) / max(stats(dry_mix)['peak'], 1e-12)
            dry_wav = BASE / 'dry' / (key + '.wav')
            ff(['-i', dry_mix, '-af', f'volume={dry_gain}', '-c:a', 'pcm_s24le', dry_wav])
            audition = BASE / 'auditions' / (key + '-dry-then-designed.wav')
            ff(['-i', dry_wav, '-f', 'lavfi', '-t', '0.4', '-i', f'anullsrc=r={RATE}:cl=mono', '-i', wav, '-filter_complex', '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]', '-map', '[out]', '-c:a', 'pcm_s24le', audition])
            shutil.copy2(ogg, runtime / ogg.name)
            if ogg_stats['rail_samples'] or ogg_stats['peak_dbfs'] > target + .03:
                raise RuntimeError('Decoded OGG clipping/target failure: ' + key)
            bus = 'Weapons' if key.endswith('_fire') else 'World'
            manifest['cues'][key] = {'description': description, 'source_ids': [e['source_id'] for e in edits], 'edits': metadata, 'export_peak_target_dbfs': target, 'final_mix_graph': graph, 'final_export_gain': final_gain, 'bus': bus, 'gain_db': 0,
                                    'file': str(wav.relative_to(BASE)), 'sha256': sha(wav), 'technical': stats(wav), 'ogg_file': str(ogg.relative_to(BASE)), 'ogg_sha256': sha(ogg), 'ogg_technical': ogg_stats,
                                    'dry_file': str(dry_wav.relative_to(BASE)), 'dry_sha256': sha(dry_wav), 'dry_mix_graph': dry_graph, 'dry_final_gain': dry_gain, 'dry_edits': 'Same archival-source excerpts, mono resample, per-layer gain match and placement only. No pitch/EQ or fades. Composite dry reference is a mixture, not an original source.',
                                    'audition_file': str(audition.relative_to(BASE)), 'audition_sha256': sha(audition), 'audition_order': 'Dry reference, 0.4 seconds silence, designed candidate.', 'runtime': str((runtime / ogg.name).relative_to(PROJECT))}
            ledger['cues'][key] = {'file': 'res://' + str((runtime / ogg.name).relative_to(PROJECT)), 'bus': bus, 'gain_db': 0, 'source_manifest': 'concepts/audio-v6/manifest.json', 'source_ids': [e['source_id'] for e in edits]}
            print(key, 'duration', duration, 'decoded peak dBFS', round(ogg_stats['peak_dbfs'], 2), 'rails', ogg_stats['rail_samples'], flush=True)
    for path, expected in old_files.items():
        if sha(PROJECT / path.removeprefix('res://')) != expected: raise RuntimeError('Existing audio changed: ' + path)
    if {k: ledger['cues'][k] for k in old_cues} != baseline['cues']: raise RuntimeError('Existing ledger entries changed')
    (BASE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    ledger_path.write_text(json.dumps(ledger, indent=2) + '\n')
    print('ARSENAL_AUDIO_BUILT: 13 original-source-only cues; nine preserved CC0 originals; 35 previous entries/music bytes unchanged. Listening acceptance pending.', flush=True)


def verify():
    manifest = json.loads((BASE / 'manifest.json').read_text())
    if len(manifest['cues']) != 13 or len(manifest['sources']) != 9:
        raise RuntimeError('Unexpected arsenal/source count')
    for source in manifest['sources']:
        if sha(PROJECT / source['original']) != source['original_sha256']:
            raise RuntimeError('Original source changed: ' + source['id'])
        for path, expected in source['license_evidence_sha256'].items():
            if sha(PROJECT / path) != expected: raise RuntimeError('License evidence changed: ' + path)
    for key, cue in manifest['cues'].items():
        for file_key, hash_key in [('file', 'sha256'), ('dry_file', 'dry_sha256'), ('ogg_file', 'ogg_sha256'), ('audition_file', 'audition_sha256')]:
            if sha(BASE / cue[file_key]) != cue[hash_key]: raise RuntimeError('Output changed: ' + key + '/' + file_key)
        for edit in cue['edits']:
            if sha(BASE / edit['source_excerpt']) != edit['source_excerpt_sha256']:
                raise RuntimeError('Source excerpt changed: ' + edit['source_excerpt'])
        if (PROJECT / cue['runtime']).read_bytes() != (BASE / cue['ogg_file']).read_bytes():
            raise RuntimeError('Runtime copy changed: ' + key)
        measured = stats(PROJECT / cue['runtime'])
        if measured['rail_samples'] or measured['peak_dbfs'] > cue['export_peak_target_dbfs'] + .03:
            raise RuntimeError('Decoded target/clipping failure: ' + key)
        if abs(measured['seconds'] - cue['ogg_technical']['seconds']) > 1 / RATE:
            raise RuntimeError('Output duration changed: ' + key)
    for path, expected in manifest['preservation']['existing_audio_sha256'].items():
        if sha(PROJECT / path.removeprefix('res://')) != expected:
            raise RuntimeError('Existing audio changed: ' + path)
    before = json.loads((BASE / manifest['preservation']['runtime_before']).read_text())
    runtime = json.loads((PROJECT / 'assets/audio/runtime-cues.json').read_text())
    if {k: runtime['cues'][k] for k in before['cues']} != before['cues']:
        raise RuntimeError('Existing runtime metadata changed')
    if runtime['level_music'] != before['level_music'] or runtime['status'] != before['status']:
        raise RuntimeError('Existing runtime music/status changed')
    print('ARSENAL_AUDIO_VERIFY_OK: nine original/license hashes, source excerpts, 13 dry/designed/OGG/auditions, runtime copies, decoded levels, 35 old entries/audio and music verified.')


if __name__ == '__main__':
    if '--verify-only' in sys.argv: verify()
    else: main()
