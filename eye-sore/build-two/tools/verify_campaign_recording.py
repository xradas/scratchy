#!/usr/bin/env python3
"""Verify the finished exported Intake campaign MovieMaker capture.

This bounded postprocessor reads the native route/log/AVI, stream-copies its
PCM to WAV, and encodes its entire video/audio to H.264/AAC MP4. It neither
launches the game nor alters the source AVI. Visual samples establish only
nonblack variation; they do not constitute human visual acceptance.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys

import verify_arsenal_recordings as media

ROOT = Path(__file__).resolve().parents[1]
SOURCE_COMMIT = '99a7b19eb2b7c7cdd4cbb784d9b955f71ea9437b'
ELF_SHA256 = '645c225be09dfee6f1cdc296f54802b171f45f83f4caa6050d029473196f4728'
LEVEL = 'pale_ward_01'
REQUIRED_FLAGS = ('breaker', 'power', 'brass_key', 'release', 'red_key',
                  'clear_arena_one', 'clear_arena_two', 'clear_final_arena',
                  'exit_control', 'exit')
NORMAL_SEED = {'health': 100, 'armor': 50, 'ammo_pistol': 36,
               'ammo_shotgun': 12, 'ammo_rivets': 0, 'ammo_rockets': 0,
               'owned_weapons': ['pistol', 'shotgun', 'melee']}
NORMAL_BASELINE = {'health': 100, 'armor': 50, 'pistol': 36, 'shells': 12,
                   'rivets': 0, 'rockets': 0, 'owned_weapons':
                   ['pistol', 'shotgun', 'melee'], 'kills': 0, 'total': 36,
                   'shots': 0}


def frozen_seed():
    """Read the declared route fixture from the exact exported source commit."""
    repo = Path(subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT,
                               capture_output=True, text=True, check=True).stdout.strip())
    rel = (ROOT / 'resources/campaign/route-seeds.json').relative_to(repo)
    blob = f'{SOURCE_COMMIT}:{rel.as_posix()}'
    output = subprocess.run(['git', 'show', blob], cwd=ROOT, capture_output=True,
                            text=True, check=True).stdout
    return json.loads(output)['seeds'][LEVEL], blob


def check_route(path, launch_path, avi, native_log, log):
    data = json.loads(path.read_text())
    media.require(data.get('campaign_level') == LEVEL and data.get('theme') == 'pale_ward',
                  'Campaign route level/theme differs from Intake')
    media.require(data.get('scene') == 'res://scenes/campaign/pale_ward_01.tscn' and
                  data.get('route_resource') == 'res://resources/campaign/pale_ward_01-route.json' and
                  data.get('seed_resource') == 'res://resources/campaign/route-seeds.json',
                  'Route/scene/seed resource differs from Intake')
    media.require(data.get('completed') is True and data.get('failures') == [] and
                  data.get('completion_menu_paused') is True and data.get('editor_feature') is False,
                  'Actual exported Main route did not complete cleanly')
    seed, seed_blob = frozen_seed()
    media.require(seed == NORMAL_SEED and data.get('seed') == seed and
                  data.get('baseline') == NORMAL_BASELINE,
                  'Initial state differs from frozen source-declared normal loadout')
    media.require(data.get('secret_used') is False and
                  all(data.get('flags', {}).get(flag) is True for flag in REQUIRED_FLAGS),
                  'Required progression or no-secret check failed')
    media.require(data.get('total_enemies') == 36 and data.get('kills') == 32 and
                  data.get('shots', 0) > 0 and data.get('health', 0) > 0,
                  'Expected surviving ordinary combat route is absent')
    media.require(any(event.get('mechanism') == 'ExitControl' and
                      event.get('input') == 'E' and event.get('accepted') is True
                      for event in data.get('interactions', [])),
                  'Real accepted ExitControl interaction is absent')
    ammo = data.get('final_ammo', {})
    media.require(set(ammo) == {'pistol', 'shells', 'rivets', 'rockets'} and
                  all(isinstance(v, (int, float)) and math.isfinite(v) and
                      v >= 0 and int(v) == v for v in ammo.values()),
                  'Final finite ammunition ledger is invalid')
    executable = Path(data['executable']).resolve()
    media.require(executable.is_file() and executable.read_bytes()[:4] == b'\x7fELF',
                  'Route executable is not an available ELF')
    elf_record = media.record(executable)
    media.require(elf_record['sha256'] == ELF_SHA256,
                  'Route executable differs from declared fresh ELF')
    build_path = Path(data['source_package_dir']) / 'BUILD.json'
    build = json.loads(build_path.read_text())
    media.require(build.get('source_commit') == SOURCE_COMMIT and
                  build.get('executable', {}).get('sha256') == ELF_SHA256,
                  'Export build provenance differs from frozen source/ELF')
    launch = json.loads(launch_path.read_text())
    expected_command = [str(executable), '--fixed-fps', '30', '--disable-vsync',
                        '--write-movie', str(avi), '--log-file', str(native_log), '--',
                        '--campaign-route-test', '--campaign-level=pale_ward_01',
                        '--release-report-dir=' + str(path.parent),
                        '--automated-input', '--force-offscreen-draw']
    media.require(launch.get('command') == expected_command,
                  'Observed native process command differs from matching capture/route')
    media.require(isinstance(launch.get('pid'), int) and launch['pid'] > 0,
                  'Observed native process lacks PID')
    log.write('CAMPAIGN_ROUTE_CHECK_OK ' + LEVEL)
    return {**media.record(path), 'level': LEVEL, 'completed': True,
            'secret_used': False, 'ordinary_seed': seed,
            'frozen_seed_blob': seed_blob, 'baseline': data['baseline'],
            'health': data['health'], 'kills': data['kills'],
            'total_enemies': data['total_enemies'], 'shots': data['shots'],
            'flags': data['flags'], 'accepted_exit_control': True,
            'final_ammo': ammo, 'physics_seconds': data['physics_seconds'],
            'scope': data['scope'], 'executable': elf_record,
            'export_build': media.record(build_path), 'source_commit': SOURCE_COMMIT,
            'launch_observation': {**media.record(launch_path),
                                   'source': launch['source'],
                                   'command': launch['command'],
                                   'note': launch['note']},
            'association': 'Coordinator-confirmed completed native capture, process argument observation, matching native log and route receipt associate these artifacts; video pixels alone cannot establish executable identity.'}


def verify(args):
    directory = args.recordings_dir.resolve()
    media.require(directory.is_absolute() and not directory.is_relative_to(ROOT),
                  'Recordings must remain outside the project')
    avi = directory / 'intake.avi'
    native_log = (args.log or directory / 'intake.log').resolve()
    route_path = args.route_report.resolve()
    launch_path = args.launch_observation.resolve()
    report_path = args.report.resolve()
    for path in (avi, native_log, route_path, launch_path):
        media.require(path.is_file(), f'Required completed capture evidence missing: {path}')
    original_stat = (avi.stat().st_size, avi.stat().st_mtime_ns)
    helper_hash = media.sha(Path(__file__))
    reused_helper_hash = media.sha(Path(media.__file__))
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:8])
    log_path = directory / 'logs/intake-recording-verification.log'
    if log_path.is_file():
        archive = log_path.with_name('intake-recording-verification-previous-' +
                                     media.sha(log_path)[:16] + '.log')
        shutil.copyfile(log_path, archive)
    log = media.Log(log_path)
    log.write('Campaign recording postprocess started UTC ' + datetime.now(timezone.utc).isoformat())
    route = check_route(route_path, launch_path, avi, native_log, log)
    native_text = native_log.read_text(errors='replace')
    media.require('CAMPAIGN_ROUTE_FAILED' not in native_text and
                  ('OpenGL API' in native_text or 'Vulkan API' in native_text) and
                  'Movie Maker mode enabled, recording movie in 1280×720 @ 30 FPS' in native_text,
                  'Native log lacks successful graphics/MovieMaker declaration or reports route failure')
    markers = [json.loads(line.split('CAMPAIGN_ROUTE_OK ', 1)[1])
               for line in native_text.splitlines() if 'CAMPAIGN_ROUTE_OK ' in line]
    media.require(len(markers) == 1 and markers[0].get('level') == LEVEL and
                  markers[0].get('failures') == [] and
                  Path(markers[0].get('receipt', '')).resolve() == route_path,
                  'Native success marker does not match route receipt')
    native_log_record = media.record(native_log)
    original = media.record(avi)
    source = media.video_info(media.probe(avi, log, True))
    media.require(source['format']['format_name'] == 'avi' and
                  source['audio']['codec_name'].startswith('pcm_'),
                  'Source is not MovieMaker AVI with PCM audio')
    media.require(source['frames'] == 6527, 'Finished capture does not contain expected 6527 frames')
    pcm = media.raw_pcm(avi, source['audio'], log)
    media.require(abs(pcm['seconds'] - source['seconds']) <= media.TOLERANCE,
                  'Source PCM/video duration differs by over one frame')
    diversity = media.native_frame_diversity(avi, source['frames'], log)

    wav = directory / 'intake-master.wav'
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
                  'Master WAV PCM does not exactly equal source AVI PCM')

    mp4 = directory / 'intake.mp4'
    log.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', '-threads', '2', '-i', avi,
             '-map', '0:v:0', '-map', '0:a:0', '-c:v', 'libx264', '-threads', '4',
             '-preset', 'fast', '-crf', '16', '-pix_fmt', 'yuv420p',
             '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', mp4])
    encoded = media.video_info(media.probe(mp4, log, True), source['frames'])
    media.require('mp4' in encoded['format']['format_name'] and
                  encoded['video']['codec_name'] == 'h264' and
                  encoded['audio']['codec_name'] == 'aac',
                  'Delivery is not full-frame H.264/AAC MP4')
    media.require(encoded['video']['pix_fmt'] in ('yuv420p', 'yuvj420p'),
                  'Delivery is not 8-bit planar 4:2:0')
    if encoded['video']['pix_fmt'] == 'yuvj420p':
        media.require(encoded['video'].get('color_range') == 'pc' and
                      source['video'].get('color_range') == 'pc',
                      'Unexpected full-range delivery declaration')
    decoded = media.decoded_aac(mp4, encoded['audio'], log)
    media.require(abs(decoded['decoded_seconds'] - pcm['seconds']) <= media.TOLERANCE and
                  abs(decoded['decoded_seconds'] - encoded['seconds']) <= media.TOLERANCE,
                  'Delivery AAC duration differs from full source by over one frame')
    media.require(original_stat == (avi.stat().st_size, avi.stat().st_mtime_ns) and
                  media.sha(avi) == original['sha256'],
                  'Original AVI changed during verification')
    media.require(media.sha(route_path) == route['sha256'] and
                  media.sha(native_log) == native_log_record['sha256'] and
                  media.sha(launch_path) == route['launch_observation']['sha256'],
                  'Native route/log/launch evidence changed during verification')
    log.write('CAMPAIGN_RECORDING_VERIFY_OK ' + LEVEL)
    media.require(media.sha(Path(__file__)) == helper_hash and
                  media.sha(Path(media.__file__)) == reused_helper_hash,
                  'Verifier implementation changed during processing')
    result = {
        'schema_version': 1, 'campaign_level': LEVEL, 'status': 'passed',
        'source_commit': SOURCE_COMMIT, 'expected_elf_sha256': ELF_SHA256,
        'method': 'Completed exported ELF native MovieMaker capture at fixed 30 FPS; CPU verification, PCM stream copy and full-length H.264/AAC encode only.',
        'scope': 'Automated physical route with real E interactions, normal finite loadout, AI and damage, no secrets. Simulation timing and numerical media checks do not establish human pacing, visual acceptance or listening acceptance.',
        'original_avi': original, 'native_video': source, 'master_pcm': pcm,
        'native_frame_diversity': diversity,
        'master_wav': {**media.record(wav), 'payload': wav_pcm,
                       'processing': 'Unchanged source PCM packet stream copied to stereo 48 kHz WAV; exact payload SHA256/length/frame equality, no filters or gain.'},
        'mp4': {**media.record(mp4), 'video': encoded, 'decoded_audio': decoded,
                'processing': 'Full 6527-frame H.264 libx264 fast CRF16 8-bit 4:2:0 and AAC256k faststart; no trim, overlays, gain, fades or additional streams. Video/AAC are lossy; pixel/sample equality is not claimed.'},
        'route': route, 'native_log': {**native_log_record,
                                      'successful_campaign_marker': markers[0]},
        'duration_tolerance_seconds': media.TOLERANCE,
        'verification_log': media.record(log.path),
        'helper': {'path': str(Path(__file__).relative_to(ROOT)), 'sha256': helper_hash,
                   'reused_analysis': {'path': str(Path(media.__file__).relative_to(ROOT)),
                                       'sha256': reused_helper_hash}},
        'cpu_affinity': sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else 'unavailable; explicit encoder/decoder thread limits apply',
        'human_acceptance': 'pending',
        'verified_utc': datetime.now(timezone.utc).isoformat(),
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(f'CAMPAIGN_RECORDING_OK {LEVEL}: {source["frames"]} frames; '
          f'{pcm["seconds"]:.3f}s exact WAV PCM; MP4={mp4}; receipt={report_path}',
          flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recordings-dir', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--route-report', type=Path, default=Path('/tmp/eyesore-campaign-export-native/pale_ward_01-campaign-route.json'))
    parser.add_argument('--log', type=Path, help='Completed native MovieMaker log; defaults to recordings-dir/intake.log')
    parser.add_argument('--launch-observation', type=Path, default=ROOT / 'verification/campaign-v3/release/intake-launch-observation.json')
    args = parser.parse_args()
    try:
        verify(args)
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('CAMPAIGN_RECORDING_FAILED: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
