"""Coordinator-authored creature voice design from preserved CC0 performances.

Versioned outputs only. Duration-preserving lowered formants, layered throats,
harmonic rasp and restrained fast amplitude modulation; no reverb/wet layers.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import tempfile

BASE = Path(__file__).resolve().parent
PROJECT = BASE.parents[1]
PREVIOUS = BASE.parent / 'audio-v3'
KEYS = ['unsealed_hurt', 'vessel_hurt', 'unsealed_death', 'vessel_death',
        'unsealed_attack_warning', 'vessel_attack_warning']


def run(args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def ff(args):
    return run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-y', *args])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stats(path):
    values = array.array('f')
    values.frombytes(ff(['-i', str(path), '-ac', '1', '-ar', '48000', '-f', 'f32le', '-']))
    assert values and all(math.isfinite(x) for x in values)
    metadata = json.loads(run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'json', str(path)]))
    return {'seconds': float(metadata['format']['duration']), 'decoded_seconds': len(values)/48000, 'peak': max(abs(x) for x in values),
            'rms': math.sqrt(sum(x*x for x in values)/len(values)),
            'rail_samples': sum(abs(x) >= .9999 for x in values)}


def main():
    old = json.loads((PREVIOUS/'manifest.json').read_text())
    runtime = PROJECT/'assets/audio/demonic-v1'
    runtime.mkdir(parents=True, exist_ok=True)
    for directory in ['cues', 'previous', 'auditions']:
        (BASE/directory).mkdir(exist_ok=True)
    sources = {s['id']: s for s in old['sources']}
    manifest = {'stage': 'Demonic creature voice correction, 10 October 2026',
                'scope': 'Six creature vocals only; music/player/weapon/material contacts unchanged. Technical checks do not establish human listening approval.',
                'design': 'Distinct dry layered low throats and harmonic rasp; shifted pitch/formants with duration compensation. No unprocessed human layer, reverb, echo, wet foley or animal sources.',
                'sources': [], 'cues': {}}
    with tempfile.TemporaryDirectory(prefix='pale-ward-voices-') as directory:
        temp = Path(directory)
        for key in KEYS:
            previous = old['cues'][key]
            edit = previous['edits'][0]
            source = PREVIOUS/edit['original']
            assert sha(source) == edit['original_sha256']
            reference = PROJECT/'assets/audio/cues'/f'{key}.ogg'
            baseline = stats(reference)
            (BASE/'previous'/reference.name).write_bytes(reference.read_bytes())
            raw = temp/'raw.wav'
            ff(['-i', str(source), '-ss', str(edit['start_seconds']), '-t', str(edit['duration_seconds']),
                '-ar', '48000', '-ac', '1', '-c:a', 'pcm_f32le', str(raw)])
            duration = baseline['seconds']
            # Normalize the selected recording before controlled nonlinear drive.
            input_gain = .80/max(stats(raw)['peak'], 1e-8)
            vessel = key.startswith('vessel')
            layers = [(.49, 1.0, 3200, 31, .18), (.33, .35, 850, 23, .13), (.76, .24, 5400, 47, .22)] if vessel else [(.62, 1.0, 4800, 39, .18), (.43, .40, 1100, 29, .12), (.87, .22, 6200, 53, .24)]
            graph = [f'[0:a]volume={input_gain},asplit=3[a][b][c]']
            details = []
            for index, (ratio, gain, cutoff, rate, depth) in enumerate(layers):
                # All atempo stages remain <=2 for duration compensation.
                tempo = 1/ratio
                stages = []
                while tempo > 2:
                    stages.append('atempo=2'); tempo /= 2
                stages.append(f'atempo={tempo}')
                filters = f'asetrate=48000*{ratio},aresample=48000,'+','.join(stages)+f',highpass=f=65,lowpass=f={cutoff},volume=4,asoftclip=type=tanh:threshold=0.65:oversample=4,tremolo=f={rate}:d={depth},volume={gain},apad,atrim=duration={duration}'
                graph.append(f'[{"abc"[index]}]{filters}[l{index}]')
                details.append({'pitch_ratio': ratio, 'gain': gain, 'filters': filters})
            graph.append(f'[l0][l1][l2]amix=inputs=3:normalize=0,highpass=f=60,afade=t=in:d=0.003,afade=t=out:st={duration-.035}:d=0.035[out]')
            mixed = temp/'mixed.wav'
            ff(['-i', str(raw), '-filter_complex', ';'.join(graph), '-map', '[out]', '-c:a', 'pcm_f32le', str(mixed)])
            measured = stats(mixed)
            gain = min(baseline['rms']/max(measured['rms'], 1e-8), .38/max(measured['peak'], 1e-8))
            wav = BASE/'cues'/f'{key}.wav'
            ff(['-i', str(mixed), '-af', f'volume={gain}', '-c:a', 'pcm_s24le', str(wav)])
            ogg = runtime/f'{key}.ogg'
            ff(['-i', str(wav), '-c:a', 'libvorbis', '-q:a', '6', str(ogg)])
            # Equal-level old/new reference, gap .35s. Never used as a gameplay cue.
            audition = BASE/'auditions'/f'{key}-before-after.wav'
            ff(['-i', str(reference), '-i', str(wav), '-filter_complex',
                f'[0:a]aresample=48000,aformat=channel_layouts=mono,apad,atrim=duration={duration+.35}[old];[old][1:a]concat=n=2:v=0:a=1[out]',
                '-map', '[out]', '-c:a', 'pcm_s16le', str(audition)])
            final = stats(ogg)
            assert abs(final['seconds']-duration) < .001 and final['rail_samples'] == 0
            record = dict(sources[previous['source_ids'][0]])
            record['original'] = str(source.relative_to(PROJECT))
            record['license_evidence'] = [str((PREVIOUS/e).relative_to(PROJECT)) for e in record['license_evidence']]
            record['license_evidence_sha256'] = {str((PREVIOUS/e).relative_to(PROJECT)): digest for e, digest in record['license_evidence_sha256'].items()}
            manifest['sources'].append(record)
            manifest['cues'][key] = {'source_id': record['id'], 'original_sha256': sha(source),
                'excerpt_start_seconds': edit['start_seconds'], 'excerpt_duration_seconds': edit['duration_seconds'],
                'layers': details, 'filter_graph': ';'.join(graph), 'input_gain': input_gain, 'final_gain': gain,
                'level_matching': 'RMS matched to preceding runtime cue, limited to peak0.38 before Ogg encoding.',
                'previous_runtime': str(reference.relative_to(PROJECT)), 'previous_sha256': sha(reference),
                'wav': str(wav.relative_to(PROJECT)), 'wav_sha256': sha(wav),
                'runtime': str(ogg.relative_to(PROJECT)), 'runtime_sha256': sha(ogg),
                'before_after': str(audition.relative_to(PROJECT)), 'before_after_sha256': sha(audition),
                'previous_technical': baseline, 'new_technical': final}
            print(key, 'duration', round(duration,3), 'RMS delta dB', round(20*math.log10(final['rms']/baseline['rms']),2), 'peak', round(final['peak'],3))
    (BASE/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')


if __name__ == '__main__':
    main()
