#!/usr/bin/env python3
"""Verify and deliver a completed native Breach campaign MovieMaker capture.

The exported game and capture must have finished before this tool runs. The
source AVI, route receipt, native log, launch observation and BUILD.json are
read-only inputs. WAV is a PCM stream copy; MP4 uses the complete source video
and audio without filters, trims, gain, overlays or extra streams. Numerical
media checks do not establish human visual or listening acceptance.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys

import verify_arsenal_recordings as media


ROOT = Path(__file__).resolve().parents[1]
LEVEL = 'pale_ward_03'
GUNS = ('twin_shotgun', 'rivet_cannon', 'siege_launcher')
FLAGS = ('breaker', 'power', 'brass_key', 'release', 'red_key',
         'clear_arena_one', 'clear_arena_two', 'clear_final_arena',
         'exit_control', 'exit')


def frozen_json(commit, relative_path):
    repo = Path(subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT,
                               capture_output=True, text=True, check=True).stdout.strip())
    project_path = ROOT.relative_to(repo)
    blob = f'{commit}:{(project_path / relative_path).as_posix()}'
    data = subprocess.run(['git', 'show', blob], cwd=ROOT, capture_output=True,
                          text=True, check=True).stdout
    return json.loads(data), {'blob': blob, 'sha256': hashlib.sha256(data.encode()).hexdigest()}


def finite_integer(value, minimum=0):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value) and value >= minimum and int(value) == value)


def command_value(command, flag):
    media.require(command.count(flag) == 1, f'Launch must contain one {flag}')
    index = command.index(flag)
    media.require(index + 1 < len(command), f'Launch value missing after {flag}')
    return command[index + 1]


def validate_launch(path, executable, avi, native_log, route_path):
    data = json.loads(path.read_text())
    command = data.get('command')
    media.require(isinstance(command, list) and all(isinstance(x, str) for x in command)
                  and command and Path(command[0]).resolve() == executable,
                  'Observed launch does not identify this executable')
    media.require(finite_integer(data.get('pid'), 1) and data.get('source'),
                  'Launch observation lacks process PID/source')
    media.require(command_value(command, '--fixed-fps') == '30' and
                  command.count('--disable-vsync') == 1,
                  'Capture was not launched at fixed 30 FPS without VSync')
    media.require(Path(command_value(command, '--write-movie')).resolve() == avi and
                  Path(command_value(command, '--log-file')).resolve() == native_log,
                  'Launch MovieMaker AVI/log paths differ from submitted artifacts')
    media.require(command.count('--') == 1, 'Launch game-argument separator missing')
    game_args = command[command.index('--') + 1:]
    expected = {'--campaign-route-test', f'--campaign-level={LEVEL}',
                '--use-heavy-weapons', '--automated-input'}
    media.require(expected.issubset(game_args) and
                  f'--release-report-dir={route_path.parent}' in game_args and
                  '--campaign-all-levels' not in game_args and
                  not any(value.startswith('--stage=') for value in game_args),
                  'Launch was not the isolated Breach heavy campaign route')
    return {**media.record(path), 'pid': data['pid'], 'source': data['source'],
            'command': command, 'note': data.get('note', '')}


def validate_build(path, executable, source_commit):
    build = json.loads(path.read_text())
    elf = media.record(executable)
    media.require(executable.read_bytes()[:4] == b'\x7fELF', 'Capture executable is not ELF')
    metadata = build.get('executable', {})
    media.require(build.get('source_commit') == source_commit and
                  build.get('source_head', source_commit) == source_commit and
                  build.get('source_git_status', '') == '' and
                  metadata.get('sha256') == elf['sha256'] and
                  metadata.get('bytes') == elf['bytes'] and
                  metadata.get('path') == executable.name and
                  metadata.get('pck') == 'embedded',
                  'BUILD source/embedded ELF identity does not match submitted export')
    media.require(str(build.get('engine', '')).startswith('4.7.2.stable'),
                  'Build metadata is not the pinned Godot 4.7.2 release')
    return {'build': media.record(path), 'executable': elf,
            'source_commit': source_commit, 'engine': build['engine'],
            'source_tree_sha256': build.get('source_tree_sha256')}


def validate_route(path, executable, source_commit, log):
    data = json.loads(path.read_text())
    catalog, catalog_blob = frozen_json(source_commit, Path('resources/campaign/catalog.json'))
    seeds, seed_blob = frozen_json(source_commit, Path('resources/campaign/route-seeds.json'))
    budget, budget_blob = frozen_json(source_commit, Path('resources/campaign/balance-budget.json'))
    catalog_levels = [level for chapter in catalog['chapters'] for level in chapter['levels']]
    matches = [level for level in catalog_levels if level['id'] == LEVEL]
    media.require(len(matches) == 1 and LEVEL in seeds.get('seeds', {}),
                  'Breach or its finite seed is absent from frozen source')
    declared = matches[0]
    seed = seeds['seeds'][LEVEL]
    media.require(data.get('campaign_level') == LEVEL and
                  data.get('theme') == declared['theme'] and
                  data.get('scene') == declared['scene'] and
                  data.get('route_resource') == f'res://resources/campaign/{LEVEL}-route.json' and
                  data.get('seed_resource') == 'res://resources/campaign/route-seeds.json' and
                  data.get('seed') == seed,
                  'Route scene/theme/seed differs from frozen source')
    media.require(data.get('completed') is True and data.get('failures') == [] and
                  data.get('completion_menu_paused') is True and
                  data.get('editor_feature') is False and
                  data.get('use_heavy_weapons') is True,
                  'Exported Main Breach heavy route did not complete cleanly')
    media.require(Path(data.get('executable', '')).resolve() == executable and
                  Path(data.get('source_package_dir', '')).resolve() == executable.parent,
                  'Route executable/package identity differs from submitted export')
    baseline = data.get('baseline', {})
    for field, seed_field in [('health', 'health'), ('armor', 'armor'),
                              ('pistol', 'ammo_pistol'), ('shells', 'ammo_shotgun'),
                              ('rivets', 'ammo_rivets'), ('rockets', 'ammo_rockets')]:
        media.require(baseline.get(field) == seed[seed_field],
                      f'Actual entry {field} differs from frozen finite seed')
    media.require(set(baseline.get('owned_weapons', [])) == set(seed['owned_weapons']) and
                  len(baseline.get('owned_weapons', [])) == len(seed['owned_weapons']) and
                  baseline.get('kills') == 0 and baseline.get('shots') == 0 and
                  baseline.get('total') == data.get('total_enemies'),
                  'Entry ownership/roster/shots differ from declared campaign seed')
    media.require(data.get('secret_used') is False and
                  all(data.get('flags', {}).get(flag) is True for flag in FLAGS),
                  'Required progression or no-secret route check failed')
    media.require(any(event.get('mechanism') == 'ExitControl' and
                      event.get('input') == 'E' and event.get('accepted') is True
                      for event in data.get('interactions', [])),
                  'Real accepted campaign exit interaction is absent')
    media.require(finite_integer(data.get('kills'), 1) and
                  finite_integer(data.get('total_enemies'), data['kills']) and
                  finite_integer(data.get('shots'), 1) and
                  isinstance(data.get('health'), (int, float)) and data['health'] > 0 and
                  isinstance(data.get('segments'), list) and len(data['segments']) > 0 and
                  isinstance(data.get('physics_seconds'), (int, float)) and
                  math.isfinite(data['physics_seconds']) and data['physics_seconds'] > 0,
                  'Route lacks surviving real physical combat and elapsed simulation')
    caps = budget['ammo_caps']
    media.require(data.get('ammo_caps') == caps,
                  'Actual route ammo caps differ from frozen balance resource')
    for name in ('entry_ammo', 'peak_ammo', 'exit_ammo', 'final_ammo'):
        values = data.get(name, {})
        media.require(set(values) == set(caps) and
                      all(finite_integer(values[kind]) and values[kind] <= caps[kind]
                          for kind in caps),
                      f'Invalid or over-cap {name} ledger')
    media.require(data['exit_ammo'] == data['final_ammo'] and
                  all(data['peak_ammo'][kind] >= max(data['entry_ammo'][kind],
                                                     data['exit_ammo'][kind]) for kind in caps) and
                  data.get('siege_self_hits') == 0,
                  'Route ammo peak/finale or Siege self-hit ledger disagrees')
    shots, kills = data.get('weapon_shots', {}), data.get('weapon_kills', {})
    media.require(all(finite_integer(shots.get(gun), 1) and
                      finite_integer(kills.get(gun), 1) for gun in GUNS),
                  'Breach heavy route lacks actual shots and kills for each heavy gun')
    log.write('BALANCE_ROUTE_CHECK_OK ' + LEVEL)
    return {**media.record(path), 'level': LEVEL, 'completed': True,
            'finite_seed': seed, 'baseline': baseline, 'kills': data['kills'],
            'total_enemies': data['total_enemies'], 'shots': data['shots'],
            'health': data['health'], 'flags': data['flags'], 'secret_used': False,
            'accepted_exit_control': True, 'weapon_shots': shots,
            'weapon_kills': kills, 'entry_ammo': data['entry_ammo'],
            'exit_ammo': data['exit_ammo'], 'peak_ammo': data['peak_ammo'],
            'ammo_caps': caps, 'physics_seconds': data['physics_seconds'],
            'frozen_source_blobs': [catalog_blob, seed_blob, budget_blob],
            'scope': data.get('scope', '')}


def verify(args):
    executable, avi, mp4, wav = (path.resolve() for path in
                                 (args.executable, args.avi, args.mp4, args.wav))
    route_path, native_log, launch_path = (path.resolve() for path in
                                          (args.route_report, args.native_log,
                                           args.launch_evidence))
    report = args.report.resolve()
    build_path = (args.build_json or executable.parent / 'BUILD.json').resolve()
    verify_log_path = (args.verification_log or report.with_suffix('.log')).resolve()
    inputs = (executable, avi, route_path, native_log, launch_path, build_path)
    outputs = (mp4, wav, report, verify_log_path)
    media.require(all(path.is_file() for path in inputs),
                  'An executable, completed AVI, route, native log, launch observation or BUILD.json is missing')
    media.require(len(set(inputs + outputs)) == len(inputs + outputs),
                  'Media/evidence input and output paths must be distinct')
    media.require(avi.parent.is_absolute() and not avi.is_relative_to(ROOT) and
                  not mp4.is_relative_to(ROOT) and not wav.is_relative_to(ROOT),
                  'Original and delivery media must remain outside the project')
    media.require(len(args.source_commit) == 40 and
                  all(c in '0123456789abcdef' for c in args.source_commit),
                  'Source commit must be a full lowercase Git SHA')
    source_stat = (avi.stat().st_size, avi.stat().st_mtime_ns)
    helper_hash, reused_hash = media.sha(Path(__file__)), media.sha(Path(media.__file__))
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:8])
    verify_log_path.parent.mkdir(parents=True, exist_ok=True)
    if verify_log_path.is_file():
        archive = verify_log_path.with_name(verify_log_path.stem + '-previous-'
                                            + media.sha(verify_log_path)[:16] + '.log')
        shutil.copyfile(verify_log_path, archive)
    log = media.Log(verify_log_path)
    log.write('Balance recording verification started UTC '
              + datetime.now(timezone.utc).isoformat())
    build = validate_build(build_path, executable, args.source_commit)
    launch = validate_launch(launch_path, executable, avi, native_log, route_path)
    route = validate_route(route_path, executable, args.source_commit, log)
    native_text = native_log.read_text(errors='replace')
    media.require('CAMPAIGN_ROUTE_FAILED' not in native_text and
                  ('OpenGL API' in native_text or 'Vulkan API' in native_text) and
                  'Movie Maker mode enabled, recording movie in 1280×720 @ 30 FPS' in native_text,
                  'Native log lacks successful native graphics/MovieMaker declaration')
    markers = [json.loads(line.split('CAMPAIGN_ROUTE_OK ', 1)[1])
               for line in native_text.splitlines() if 'CAMPAIGN_ROUTE_OK ' in line]
    media.require(len(markers) == 1 and markers[0].get('level') == LEVEL and
                  markers[0].get('failures') == [] and
                  Path(markers[0].get('receipt', '')).resolve() == route_path,
                  'Native success marker does not match submitted route receipt')
    native_log_record = media.record(native_log)
    original = media.record(avi)
    source = media.video_info(media.probe(avi, log, True))
    media.require(source['format']['format_name'] == 'avi' and
                  source['audio']['codec_name'].startswith('pcm_'),
                  'Source is not an AVI with native PCM audio')
    pcm = media.raw_pcm(avi, source['audio'], log)
    media.require(abs(pcm['seconds'] - source['seconds']) <= media.TOLERANCE,
                  'AVI stereo PCM/video duration differs by more than one frame')
    media.require(source['seconds'] >= route['physics_seconds'] and
                  source['seconds'] - route['physics_seconds'] < 30,
                  'Movie duration does not cover route simulation plus short menu/retirement')
    diversity = media.native_frame_diversity(avi, source['frames'], log)

    wav.parent.mkdir(parents=True, exist_ok=True)
    log.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', '-i', avi,
             '-map', '0:a:0', '-vn', '-sn', '-dn', '-c:a', 'copy', wav])
    wav_data = media.probe(wav, log)
    wav_video, wav_audio = media.streams(wav_data)
    media.require(not wav_video and len(wav_audio) == 1 and
                  wav_data['format']['format_name'] == 'wav' and
                  wav_audio[0]['codec_name'] == source['audio']['codec_name'] and
                  int(wav_audio[0]['sample_rate']) == 48000 and
                  wav_audio[0]['channels'] == 2,
                  'Master WAV is not the original stereo 48 kHz PCM stream')
    wav_pcm = media.raw_pcm(wav, wav_audio[0], log, False)
    media.require(wav_pcm['native_pcm_payload_sha256'] == pcm['native_pcm_payload_sha256'] and
                  wav_pcm['native_pcm_payload_bytes'] == pcm['native_pcm_payload_bytes'] and
                  wav_pcm['decoded_frames'] == pcm['decoded_frames'],
                  'WAV PCM payload differs from source AVI')

    mp4.parent.mkdir(parents=True, exist_ok=True)
    log.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', '-threads', '2', '-i', avi,
             '-map', '0:v:0', '-map', '0:a:0', '-c:v', 'libx264', '-threads', '4',
             '-preset', 'fast', '-crf', '16', '-pix_fmt', 'yuv420p',
             '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', mp4])
    encoded = media.video_info(media.probe(mp4, log, True), source['frames'])
    media.require('mp4' in encoded['format']['format_name'] and
                  encoded['video']['codec_name'] == 'h264' and
                  encoded['audio']['codec_name'] == 'aac' and
                  encoded['video']['pix_fmt'] in ('yuv420p', 'yuvj420p'),
                  'Delivery is not full-frame H.264/AAC 8-bit 4:2:0 MP4')
    if encoded['video']['pix_fmt'] == 'yuvj420p':
        media.require(encoded['video'].get('color_range') == 'pc' and
                      source['video'].get('color_range') == 'pc',
                      'Unexpected full-range delivery declaration')
    decoded = media.decoded_aac(mp4, encoded['audio'], log)
    media.require(abs(decoded['decoded_seconds'] - pcm['seconds']) <= media.TOLERANCE and
                  abs(decoded['decoded_seconds'] - encoded['seconds']) <= media.TOLERANCE,
                  'Delivery AAC duration differs from full AVI by more than one frame')
    media.require(source_stat == (avi.stat().st_size, avi.stat().st_mtime_ns) and
                  media.sha(avi) == original['sha256'] and
                  media.sha(route_path) == route['sha256'] and
                  media.sha(native_log) == native_log_record['sha256'] and
                  media.sha(launch_path) == launch['sha256'] and
                  media.sha(build_path) == build['build']['sha256'] and
                  media.sha(executable) == build['executable']['sha256'],
                  'Capture or source evidence changed during verification')
    log.write('BALANCE_RECORDING_VERIFY_OK ' + LEVEL)
    media.require(media.sha(Path(__file__)) == helper_hash and
                  media.sha(Path(media.__file__)) == reused_hash,
                  'Verifier or reused analysis changed while processing')
    result = {
        'schema_version': 1, 'campaign_level': LEVEL, 'status': 'passed',
        'source_commit': args.source_commit, 'export': build, 'launch': launch,
        'route': route, 'native_log': {**native_log_record,
                                       'successful_campaign_marker': markers[0]},
        'original_avi': original, 'native_video': source,
        'native_frame_diversity': diversity, 'master_pcm': pcm,
        'master_wav': {**media.record(wav), 'payload': wav_pcm,
                       'processing': 'PCM packet stream copy; exact AVI/WAV payload SHA256, byte and frame equality; no gain, filters or resampling.'},
        'mp4': {**media.record(mp4), 'video': encoded, 'decoded_audio': decoded,
                'processing': 'Complete source frames; libx264 fast CRF16 yuv420p and AAC256k faststart; no trims, overlays, filters, gain, fades or additional streams. H.264/AAC are lossy.'},
        'verification_log': media.record(verify_log_path),
        'helper': {'path': str(Path(__file__).relative_to(ROOT)), 'sha256': helper_hash,
                   'reused_analysis': {'path': str(Path(media.__file__).relative_to(ROOT)),
                                       'sha256': reused_hash}},
        'duration_tolerance_seconds': media.TOLERANCE,
        'scope': 'Coordinator-submitted completed native exported Breach MovieMaker capture and matching process/log/route evidence. Isolated source-declared finite seed, heavy bot, actual AI/damage, physical movement, authoritative shots/kills and E exit; no secrets. Numeric media checks and automated fixed simulation do not prove human visual, listening or pacing acceptance.',
        'human_acceptance': 'pending',
        'verified_utc': datetime.now(timezone.utc).isoformat(),
    }
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(f'BALANCE_RECORDING_OK {LEVEL}: {source["frames"]} frames; '
          f'{pcm["seconds"]:.3f}s stereo PCM preserved; receipt={report}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('executable', 'avi', 'mp4', 'wav', 'route-report', 'native-log',
                 'launch-evidence', 'report'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--build-json', type=Path,
                        help='Export BUILD.json; defaults beside --executable')
    parser.add_argument('--verification-log', type=Path,
                        help='Tool command/decode log; defaults beside --report')
    args = parser.parse_args()
    try:
        verify(args)
    except (RuntimeError, OSError, ValueError, KeyError,
            subprocess.SubprocessError) as error:
        print('BALANCE_RECORDING_FAILED: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
