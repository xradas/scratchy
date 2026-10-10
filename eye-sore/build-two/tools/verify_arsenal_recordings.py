#!/usr/bin/env python3
"""Verify a completed exported-game MovieMaker AVI and optionally encode delivery.

Run only after the coordinator confirms the stage capture has finished:
  python3 tools/verify_arsenal_recordings.py --stage=pale_ward \
    --recordings-dir=/absolute/external/capture-directory --encode

No game launch, GPU work, source AVI edit, raster overlay, audio addition, gain,
normalization or fade occurs here. Master WAV is a PCM stream copy. Analysis
samples native full-resolution RGB frames; numerical variation is not visual
acceptance or proof of coverage. H.264/AAC delivery is explicitly lossy.
"""
import argparse
import array
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE_COMMIT = '2fb2fd496965c7bdb3cfb4ccaca5bed288a159e6'
ELF_SHA256 = '549d888194e14713b322a09f70b6b31982a8da301819b2394c42211a39c9ecd2'
STAGES = ('pale_ward', 'ash_citadel', 'occupied_line')
GUNS = ('twin_shotgun', 'rivet_cannon', 'siege_launcher')
REQUIRED_FLAGS = ('breaker', 'power', 'brass_key', 'red_key', 'release', 'clear_arena_one', 'clear_arena_two', 'clear_final_arena', 'exit_control', 'exit')
FPS = 30
TOLERANCE = 1 / FPS + 1e-6


def require(condition, message):
    if not condition: raise RuntimeError(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for chunk in iter(lambda: handle.read(4 * 1024 * 1024), b''): digest.update(chunk)
    return digest.hexdigest()


def record(path):
    path = Path(path)
    return {'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size}


class Log:
    def __init__(self, path): self.path = path; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('')
    def write(self, text):
        with self.path.open('a') as output: output.write(text.rstrip() + '\n')
    def run(self, command):
        self.write('COMMAND ' + json.dumps(list(map(str, command))))
        result = subprocess.run(list(map(str, command)), capture_output=True, text=True)
        if result.stdout: self.write('STDOUT\n' + result.stdout)
        if result.stderr: self.write('STDERR\n' + result.stderr)
        self.write('EXIT ' + str(result.returncode))
        require(result.returncode == 0, 'Command failed: ' + ' '.join(map(str, command)) + '\n' + result.stderr[-4000:])
        return result.stdout


def probe(path, log, count_frames=False):
    command = ['ffprobe', '-v', 'error', '-threads', '4']
    if count_frames: command.append('-count_frames')
    command += ['-show_streams', '-show_format', '-of', 'json', str(path)]
    return json.loads(log.run(command))


def streams(data):
    video = [stream for stream in data['streams'] if stream['codec_type'] == 'video']
    audio = [stream for stream in data['streams'] if stream['codec_type'] == 'audio']
    return video, audio


def video_info(data, expected_frames=None):
    videos, audios = streams(data)
    require(len(videos) == 1 and len(audios) == 1, 'Expected exactly one video and one audio stream')
    video, audio = videos[0], audios[0]
    require((video['width'], video['height']) == (1280, 720), 'Native output is not 1280 × 720')
    require(Fraction(video['avg_frame_rate']) == FPS and Fraction(video['r_frame_rate']) == FPS, 'Output is not exact 30 fps')
    frames = int(video.get('nb_read_frames', 0))
    require(frames > 0, 'ffprobe did not decode a positive frame count')
    if video.get('nb_frames') not in (None, 'N/A'): require(frames == int(video['nb_frames']), 'Declared and decoded video frame counts differ')
    if expected_frames is not None: require(frames == expected_frames, 'Encoded output dropped or added video frames')
    require(audio['channels'] == 2 and int(audio['sample_rate']) == 48000, 'Output audio is not stereo 48 kHz')
    require(audio.get('channel_layout') in (None, 'unknown', 'stereo'), 'Unexpected audio channel layout')
    return {'frames': frames, 'seconds': frames / FPS, 'frame_rate': FPS, 'video': video, 'audio': audio, 'format': data['format']}


def native_frame_diversity(path, frames, log):
    indices = sorted(set(round((frames - 1) * index / 23) for index in range(24)))
    expression = '+'.join(f'eq(n,{index})' for index in indices)
    command = ['ffmpeg', '-hide_banner', '-nostdin', '-v', 'error', '-threads', '2', '-i', str(path), '-map', '0:v:0', '-an', '-sn', '-dn', '-vf', 'select=' + expression.replace(',', '\\,'), '-fps_mode', 'vfr', '-pix_fmt', 'rgb24', '-f', 'rawvideo', 'pipe:1']
    log.write('COMMAND ' + json.dumps(command))
    sample_size = 1280 * 720 * 3
    rows = []
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        try:
            for index in indices:
                chunks, remaining = [], sample_size
                while remaining:
                    chunk = process.stdout.read(remaining)
                    if not chunk: break
                    chunks.append(chunk); remaining -= len(chunk)
                require(remaining == 0, 'Selected native frame could not be completely decoded')
                frame = b''.join(chunks)
                rows.append({'frame_index': index, 'native_rgb_sha256': hashlib.sha256(frame).hexdigest(), 'peak_channel_byte': max(frame), 'mean_channel_byte': sum(frame) / sample_size})
            require(process.stdout.read(1) == b'', 'Unexpected extra selected video data')
        finally:
            process.stdout.close(); code = process.wait(); errors.seek(0); error = errors.read().decode('utf-8', 'replace')
        if error: log.write('STDERR\n' + error)
        require(code == 0, 'Native frame sample decode failed: ' + error)
    unique = len({row['native_rgb_sha256'] for row in rows})
    nonblack = sum(row['peak_channel_byte'] > 5 and row['mean_channel_byte'] > .5 for row in rows)
    require(unique >= 3, 'Sampled recording is static or lacks independently distinct frames')
    require(nonblack >= 3, 'Sampled recording is all-black or has too few nonblack frames')
    return {'analysis': '24 evenly distributed native full-resolution RGB frames; no image files saved. This tests nonblack/variation only, not art acceptance or scene coverage.', 'unique_samples': unique, 'nonblack_samples': nonblack, 'samples': rows}


def raw_pcm(path, audio, log, measure=True):
    codec = audio['codec_name']
    formats = {'pcm_s16le': ('h', 2, 32768), 'pcm_s24le': (None, 3, 8388608), 'pcm_s32le': ('i', 4, 2147483648), 'pcm_f32le': ('f', 4, 1), 'pcm_f64le': ('d', 8, 1)}
    require(codec in formats, 'Unsupported original PCM representation: ' + codec)
    typecode, width, scale = formats[codec]
    channels = int(audio['channels']); sample_rate = int(audio['sample_rate'])
    require(channels == 2 and sample_rate == 48000, 'Master PCM is not stereo 48 kHz')
    command = ['ffmpeg', '-hide_banner', '-nostdin', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-vn', '-sn', '-dn', '-c:a', 'copy', '-f', 'data', 'pipe:1']
    log.write('COMMAND ' + json.dumps(command))
    digest = hashlib.sha256(); byte_count = 0; pending = b''
    squares = [0., 0.]; sums = [0., 0.]; peaks = [0., 0.]
    difference_square = 0.; nonfinite = rails = over = 0
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        try:
            while True:
                chunk = process.stdout.read(256 * 1024)
                if not chunk: break
                digest.update(chunk); byte_count += len(chunk)
                if not measure: continue
                pending += chunk
                usable = len(pending) // (width * channels) * (width * channels)
                native = pending[:usable]; pending = pending[usable:]
                if typecode:
                    samples = array.array(typecode); samples.frombytes(native)
                    if sys.byteorder != 'little': samples.byteswap()
                else:
                    samples = [int.from_bytes(native[offset:offset + 3], 'little', signed=True) for offset in range(0, len(native), 3)]
                left, right = samples[::2], samples[1::2]
                floating = codec.startswith('pcm_f')
                if floating:
                    nonfinite += sum(not math.isfinite(v) for v in samples)
                    valid_left = [v for v in left if math.isfinite(v)]; valid_right = [v for v in right if math.isfinite(v)]
                else: valid_left, valid_right = left, right
                for channel, values in enumerate((valid_left, valid_right)):
                    if values:
                        peaks[channel] = max(peaks[channel], abs(min(values)) / scale, abs(max(values)) / scale)
                        sums[channel] += sum(values) / scale
                        squares[channel] += sum(v * v for v in values) / (scale * scale)
                if floating:
                    over += sum(abs(v) > 1 for v in valid_left) + sum(abs(v) > 1 for v in valid_right)
                    rails += sum(abs(v) >= 1 for v in valid_left) + sum(abs(v) >= 1 for v in valid_right)
                    difference_square += sum((a - b) ** 2 for a, b in zip(left, right) if math.isfinite(a) and math.isfinite(b))
                else:
                    rails += samples.count(scale - 1) + samples.count(-scale)
                    difference_square += sum((a - b) ** 2 for a, b in zip(left, right)) / (scale * scale)
        finally:
            process.stdout.close(); code = process.wait(); errors.seek(0); error = errors.read().decode('utf-8', 'replace')
        if error: log.write('STDERR\n' + error)
        require(code == 0 and not pending, 'PCM packet extraction failed: ' + error)
    require(byte_count % (width * channels) == 0, 'PCM payload has partial sample frames')
    frames = byte_count // (width * channels)
    result = {'native_pcm_payload_sha256': digest.hexdigest(), 'native_pcm_payload_bytes': byte_count, 'codec': codec, 'sample_rate': sample_rate, 'channels': channels, 'decoded_frames': frames, 'seconds': frames / sample_rate, 'decode': 'Native PCM packet payload, no filters/rate/channel conversion. Integer PCM is intrinsically finite; floating PCM is explicitly checked.'}
    if measure:
        rms = [math.sqrt(value / max(1, frames)) for value in squares]
        difference_rms = math.sqrt(difference_square / max(1, frames))
        threshold = max(1e-7, max(rms) * 1e-5)
        result.update({'rms_per_channel': rms, 'peak_per_channel': peaks, 'mean_per_channel': [value / max(1, frames) for value in sums], 'difference_rms': difference_rms, 'difference_threshold': threshold, 'nonfinite_sample_count': nonfinite, 'rail_sample_count': rails, 'over_full_scale_sample_count': over, 'nonzero_each_channel': all(value > 1e-7 for value in rms), 'stereo_difference_nonzero': difference_rms > threshold})
        require(nonfinite == 0 and rails == 0 and over == 0, 'Original Master PCM contains nonfinite/rail/over-full-scale samples')
        require(result['nonzero_each_channel'] and result['stereo_difference_nonzero'], 'Original Master mix is silent in a channel or has no meaningful stereo difference')
    return result


def decoded_aac(path, audio, log):
    # AAC is lossy. Decode at its native rate/channels for structural stereo checks;
    # never assert equality to source PCM or apply this analysis to an output file.
    command = ['ffmpeg', '-hide_banner', '-nostdin', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-vn', '-sn', '-dn', '-c:a', 'pcm_f32le', '-f', 'f32le', 'pipe:1']
    log.write('COMMAND ' + json.dumps(command))
    byte_count = nonfinite = over = 0; pending = b''; squares = [0., 0.]; peaks = [0., 0.]; difference = 0.
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        try:
            while True:
                chunk = process.stdout.read(256 * 1024)
                if not chunk: break
                byte_count += len(chunk); pending += chunk
                usable = len(pending) // 8 * 8
                samples = array.array('f'); samples.frombytes(pending[:usable]); pending = pending[usable:]
                if sys.byteorder != 'little': samples.byteswap()
                nonfinite += sum(not math.isfinite(v) for v in samples)
                left, right = samples[::2], samples[1::2]
                for channel, values in enumerate((left, right)):
                    valid = [v for v in values if math.isfinite(v)]
                    if valid:
                        squares[channel] += sum(v * v for v in valid)
                        peaks[channel] = max(peaks[channel], abs(min(valid)), abs(max(valid)))
                        over += sum(abs(v) > 1 for v in valid)
                difference += sum((a - b) ** 2 for a, b in zip(left, right) if math.isfinite(a) and math.isfinite(b))
        finally:
            process.stdout.close(); code = process.wait(); errors.seek(0); error = errors.read().decode('utf-8', 'replace')
        if error: log.write('STDERR\n' + error)
        require(code == 0 and not pending, 'AAC decode failed: ' + error)
    frames = byte_count // 8; rms = [math.sqrt(v / max(1, frames)) for v in squares]; difference_rms = math.sqrt(difference / max(1, frames))
    require(nonfinite == 0 and over == 0, 'Decoded AAC has nonfinite/over-full-scale samples')
    require(all(v > 1e-7 for v in rms) and difference_rms > max(1e-7, max(rms) * 1e-5), 'Decoded AAC is silent or dual mono')
    return {'decoded_frames': frames, 'decoded_seconds': frames / 48000, 'rms_per_channel': rms, 'peak_per_channel': peaks, 'difference_rms': difference_rms, 'nonfinite_sample_count': nonfinite, 'over_full_scale_sample_count': over, 'scope': 'Lossy AAC structural decode only; no source-PCM/sample equality claim.'}


def route_check(path, stage, log):
    data = json.loads(path.read_text())
    require(data.get('stage') == stage and data.get('completed') is True and data.get('failures') == [], 'Release route is incomplete, mismatched or failed')
    require(data.get('main_integration') is True and data.get('release_checks_enabled') is True and data.get('editor_feature') is False, 'Report is not the exported actual Main release fixture')
    require(data.get('use_heavy_weapons') is True and data.get('completion_menu_paused') is True, 'Heavy mode/completion menu missing')
    require(data.get('working_directory') == '/tmp', 'Release route was not launched from /tmp')
    require(data.get('baseline') == {'health': 100., 'armor': 50., 'pistol': 36, 'shells': 12, 'kills': 0, 'total': 42, 'shots': 0}, 'Ordinary baseline health/ammo/roster differs')
    require(data.get('kills') == 39 and data.get('total') == 42 and data.get('health', 0) > 0 and data.get('shots', 0) > 0, 'Expected surviving 39-of-42 route completion')
    require(set(data.get('shortcuts', [])) == {'shortcut_one', 'shortcut_two'} and data.get('lift_round_trip') is True and data.get('secret_used') is False, 'Shortcut/lift/no-secret requirements failed')
    require(all(data.get('flags', {}).get(flag) is True for flag in REQUIRED_FLAGS), 'Required progression flags missing')
    traps = data.get('traps', {})
    require(set(traps) == {'arena_one', 'arena_two', 'final_arena'}, 'Three required trap states missing')
    require(all(t.get('triggered') is True and t.get('cleared') is True and t.get('shutters_open') is True and t.get('latched') is False for t in traps.values()), 'Traps did not trigger, clear and safely restore entrances')
    require(set(GUNS).issubset(data.get('owned_weapons', [])), 'New weapon ownership missing at route completion')
    ammo = data.get('final_ammo', {})
    require(set(ammo) == {'pistol', 'shells', 'rivets', 'rockets'} and all(isinstance(v, (int, float)) and math.isfinite(v) and v >= 0 and int(v) == v for v in ammo.values()), 'Final ordinary ammo ledger invalid')
    events = data.get('arsenal_events', [])
    shots = {}; deaths = {}; explosions = []
    for event in events:
        weapon = event.get('weapon'); kind = event.get('type'); shot_id = int(event.get('shot_id', 0))
        require(weapon in GUNS and shot_id > 0 and int(event.get('physics_tick', 0)) > 0, 'Malformed actual arsenal event')
        if kind == 'shot':
            require(shot_id not in shots, 'Duplicate authoritative shot id in route events')
            shots[shot_id] = weapon
        elif kind == 'enemy_death':
            target = event.get('target_id')
            require(target and target not in deaths and float(event.get('damage', 0)) > 0, 'Duplicate or empty heavy weapon death event')
            deaths[target] = event
        elif kind == 'ordnance_explosion':
            require(weapon == 'siege_launcher', 'Explosion assigned to another weapon'); explosions.append(shot_id)
        else: raise RuntimeError('Unexpected arsenal event type: ' + str(kind))
    for event in deaths.values(): require(shots.get(event['shot_id']) == event['weapon'], 'Death lacks its actual accepted weapon shot')
    require(len(explosions) == len(set(explosions)) and all(shots.get(sid) == 'siege_launcher' for sid in explosions), 'Explosion ownership duplicated or lacks an accepted siege launch')
    shot_counts = {gun: sum(v == gun for v in shots.values()) for gun in GUNS}
    death_counts = {gun: sum(v['weapon'] == gun for v in deaths.values()) for gun in GUNS}
    require(all(shot_counts[gun] > 0 and death_counts[gun] > 0 for gun in GUNS), 'A new gun did not actually fire and kill in this route')
    require(data.get('new_weapon_shots') == shot_counts and data.get('new_weapon_kills') == death_counts, 'Route summary disagrees with actual heavy shot/death events')
    require(len(explosions) == shot_counts['siege_launcher'], 'A siege launch lacks its single resolved explosion')
    executable = Path(data['executable']); require(executable.is_file(), 'Reported ELF unavailable')
    require(executable.read_bytes()[:4] == b'\x7fELF', 'Reported executable is not ELF')
    executable_record = record(executable); require(executable_record['sha256'] == ELF_SHA256, 'Capture executable hash differs from declared fresh ELF')
    package = Path(data['project_package_dir']); build_path = package / 'BUILD.json'
    build = json.loads(build_path.read_text())
    require(build['source_commit'] == SOURCE_COMMIT and build['executable']['sha256'] == ELF_SHA256, 'Export BUILD provenance differs')
    log.write('ROUTE_CHECK_OK ' + stage)
    return {**record(path), 'completed': True, 'ordinary_baseline': data['baseline'], 'scope': data['scope'], 'main_integration': True, 'editor_feature': False, 'working_directory': '/tmp', 'kills': data['kills'], 'total': data['total'], 'shortcuts': data['shortcuts'], 'lift_round_trip': True, 'flags': data['flags'], 'traps': traps, 'owned_weapons': data['owned_weapons'], 'final_ammo': ammo, 'new_weapon_shots': shot_counts, 'new_weapon_kills': death_counts, 'siege_explosions': len(explosions), 'physics_seconds': data['physics_seconds'], 'bot_control_seconds': data['bot_control_seconds'], 'executable': executable_record, 'export_build': record(build_path), 'source_commit': SOURCE_COMMIT, 'association': 'Stage-completion notification plus caller-selected matching receipt/log links media to the exported run; provenance is not inferred from video pixels or filenames.'}


def native_log_path(directory, stage, explicit=None):
    if explicit: return explicit.resolve()
    candidates = [directory / (stage + suffix) for suffix in ['.log', '-movie.log', '-capture.log', '-native.log', '-raw.log']]
    candidates += [directory / 'logs' / (stage + suffix) for suffix in ['.log', '-movie.log', '-capture.log', '-native.log', '-raw.log', '.raw.log']]
    matches = [path for path in candidates if path.is_file()]
    require(len(matches) == 1, 'Expected one native stage log; pass --log explicitly if its name differs or is ambiguous')
    return matches[0]


def run_stage(args):
    directory = args.recordings_dir.resolve()
    require(directory.is_absolute() and not directory.is_relative_to(ROOT), 'Recordings must remain outside Git/project')
    original = directory / (args.stage + '.avi')
    route_path = directory / 'reports' / (args.stage + '-release-route.json')
    require(original.is_file() and route_path.is_file(), 'Completed AVI or matching exported route report not available')
    initial_stat = (original.stat().st_size, original.stat().st_mtime_ns)
    helper_hash = sha(Path(__file__))
    # Cap the whole inherited process tree, including automatic filter workers.
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:8])
    log_path = directory / 'logs' / (args.stage + '-recording-verification.log')
    previous_log = None
    if log_path.is_file():
        archived = log_path.with_name(args.stage + '-recording-verification-previous-' + sha(log_path)[:16] + '.log')
        shutil.copyfile(log_path, archived)
        previous_log = record(archived)
    log = Log(log_path)
    log.write('Recording postprocess started UTC ' + datetime.now(timezone.utc).isoformat())
    route = route_check(route_path, args.stage, log)
    native_log = native_log_path(directory, args.stage, args.log)
    log_text = native_log.read_text(errors='replace')
    require('RELEASE_STAGE_ROUTE_OK' in log_text and 'RELEASE_STAGE_ROUTE_FAILED' not in log_text, 'Native log lacks successful release route or contains failure')
    require('OpenGL API' in log_text or 'Vulkan API' in log_text, 'Native log lacks a native graphics device declaration')
    markers = [json.loads(line.split('RELEASE_STAGE_ROUTE_OK ', 1)[1]) for line in log_text.splitlines() if 'RELEASE_STAGE_ROUTE_OK ' in line]
    require(len(markers) == 1 and markers[0].get('stage') == args.stage and markers[0].get('completed') is True and markers[0].get('failures') == [] and markers[0].get('kills') == route['kills'] and Path(markers[0].get('receipt', '')).resolve() == route_path.resolve(), 'Native success marker does not match this stage/route receipt')
    require('Movie Maker mode enabled, recording movie in 1280×720 @ 30 FPS' in log_text, 'Native log lacks the expected MovieMaker output declaration')
    original_record = record(original)
    data = probe(original, log, True); source = video_info(data)
    require(source['format']['format_name'] == 'avi' and source['audio']['codec_name'].startswith('pcm_'), 'Original is not MovieMaker AVI with PCM')
    pcm = raw_pcm(original, source['audio'], log)
    require(abs(pcm['seconds'] - source['seconds']) <= TOLERANCE, 'Source PCM/video duration differs by more than one 30 fps frame')
    diversity = native_frame_diversity(original, source['frames'], log)
    wav = directory / (args.stage + '-master.wav')
    log.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', '-i', original, '-map', '0:a:0', '-vn', '-sn', '-dn', '-c:a', 'copy', wav])
    wav_data = probe(wav, log); wav_audio = [s for s in wav_data['streams'] if s['codec_type'] == 'audio']
    require(len(wav_audio) == 1, 'Master WAV must contain only one audio stream')
    wav_pcm = raw_pcm(wav, wav_audio[0], log, False)
    require(wav_pcm['native_pcm_payload_sha256'] == pcm['native_pcm_payload_sha256'] and wav_pcm['native_pcm_payload_bytes'] == pcm['native_pcm_payload_bytes'], 'Master WAV does not preserve AVI PCM sample bytes')
    result = {'schema_version': 1, 'stage': args.stage, 'status': 'passed', 'source_commit': SOURCE_COMMIT, 'expected_elf_sha256': ELF_SHA256, 'method': 'Coordinator-confirmed completed fresh ELF native MovieMaker capture at fixed 30 fps. CPU verification/extraction/transcode only; original AVI unchanged.', 'scope': 'Automated aim/movement and real E input, normal AI/health/ammo, no teleport or secret supplies. Bot duration is not human pacing. Numerical recording checks do not establish human visual/listening/play acceptance.', 'original_avi': original_record, 'native_video': source, 'master_pcm': pcm, 'master_wav': {**record(wav), 'payload': wav_pcm, 'processing': 'PCM stream copy; native stereo/rate/depth, no additions, gain, normalization, overlay, fades or filters. Native PCM payload hash exactly equals AVI.'}, 'native_frame_diversity': diversity, 'route': route, 'native_log': record(native_log), 'duration_tolerance_seconds': TOLERANCE, 'human_acceptance': 'pending'}
    if args.encode or args.verify_existing_mp4:
        mp4 = directory / (args.stage + '.mp4')
        if args.encode:
            log.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', '-threads', '2', '-i', original, '-map', '0:v:0', '-map', '0:a:0', '-c:v', 'libx264', '-threads', '4', '-preset', 'fast', '-crf', '16', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', mp4])
        else:
            require(mp4.is_file() and previous_log is not None, 'Existing delivery or its prior verification/encoding log is missing')
            previous_text = Path(previous_log['path']).read_text()
            require('"-c:v", "libx264"' in previous_text and '"-crf", "16"' in previous_text and str(original) in previous_text and str(mp4) in previous_text, 'Prior log does not document this source/delivery encoding')
            log.write('VERIFY_EXISTING_MP4 without re-encoding; archived prior command/decode log ' + json.dumps(previous_log))
        encoded = video_info(probe(mp4, log, True), source['frames'])
        require(encoded['format']['format_name'].find('mp4') >= 0 and encoded['video']['codec_name'] == 'h264' and encoded['audio']['codec_name'] == 'aac', 'Encoded delivery is not H.264/AAC MP4')
        require(encoded['video']['pix_fmt'] in ('yuv420p', 'yuvj420p'), 'Delivery is not 8-bit planar 4:2:0')
        if encoded['video']['pix_fmt'] == 'yuvj420p':
            require(encoded['video'].get('color_range') == 'pc' and source['video'].get('color_range') == 'pc', 'Unexpected full-range delivery declaration')
        decoded = decoded_aac(mp4, encoded['audio'], log)
        require(abs(decoded['decoded_seconds'] - pcm['seconds']) <= TOLERANCE and abs(decoded['decoded_seconds'] - encoded['seconds']) <= TOLERANCE, 'AAC decoded duration differs from source/video by more than one frame')
        result['mp4'] = {**record(mp4), 'video': encoded, 'decoded_audio': decoded, 'processing': 'Full frame sequence, libx264 preset fast CRF16 with requested yuv420p and AAC256k faststart; ffprobe may name preserved source full-range 8-bit 4:2:0 yuvj420p. No frame overlays, source trims, additional audio, gain, normalization or fades. Video/AAC are lossy; pixel/sample equality is not claimed.', 'encoded_this_run': args.encode}
        if previous_log: result['mp4']['previous_verification_encoding_log'] = previous_log
    require(initial_stat == (original.stat().st_size, original.stat().st_mtime_ns) and sha(original) == original_record['sha256'], 'Original AVI changed during verification; stage may still be recording')
    require(sha(route_path) == route['sha256'] and sha(native_log) == result['native_log']['sha256'], 'Native route/log changed during verification')
    log.write('RECORDING_VERIFY_OK ' + args.stage)
    result['verification_log'] = record(log.path)
    require(sha(Path(__file__)) == helper_hash, 'Helper source changed while running')
    result['helper'] = {'path': str(Path(__file__).relative_to(ROOT)), 'sha256': helper_hash}
    result['native_log']['successful_stage_marker'] = markers[0]
    result['cpu_affinity'] = sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else 'unavailable; explicit decoder/encoder thread limits apply'
    result['verified_utc'] = datetime.now(timezone.utc).isoformat()
    receipt = ROOT / 'verification/arsenal-architecture-v2/release' / (args.stage + '-recording.json')
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(f'ARSENAL_RECORDING_OK {args.stage}: {source["frames"]} decoded frames; {pcm["seconds"]:.3f}s unchanged stereo PCM; 39/42 normal exported route; MP4={args.encode or args.verify_existing_mp4}; receipt={receipt}', flush=True)


def self_test():
    # Temporary detector fixtures are not gameplay, source media or evidence of a capture.
    with tempfile.TemporaryDirectory(prefix='eyesore-recording-detectors-') as temporary:
        directory = Path(temporary); log = Log(directory / 'self-test.log')
        results = []
        for name, sample, expected_pass in [
            ('stereo', lambda i: (int(8000 * math.sin(i / 11)), int(7000 * math.sin(i / 13))), True),
            ('dual_mono', lambda i: (int(8000 * math.sin(i / 11)),) * 2, False),
            ('silent_channel', lambda i: (int(8000 * math.sin(i / 11)), 0), False),
            ('positive_negative_rails', lambda i: (32767, -32768), False)]:
            path = directory / (name + '.wav'); samples = array.array('h')
            for i in range(4800): samples.extend(sample(i))
            if sys.byteorder != 'little': samples.byteswap()
            with wave.open(str(path), 'wb') as output:
                output.setparams((2, 2, 48000, 0, 'NONE', 'not compressed')); output.writeframes(samples.tobytes())
            try: raw_pcm(path, {'codec_name': 'pcm_s16le', 'channels': 2, 'sample_rate': '48000'}, log); passed = True
            except RuntimeError: passed = False
            require(passed == expected_pass, 'Audio detector failed temporary case: ' + name); results.append(name)
        for name, source, expected_pass in [('moving', 'testsrc2=size=1280x720:rate=30', True), ('black', 'color=black:size=1280x720:rate=30', False), ('static', 'color=red:size=1280x720:rate=30', False)]:
            path = directory / (name + '.avi')
            log.run(['ffmpeg', '-hide_banner', '-nostdin', '-v', 'error', '-y', '-f', 'lavfi', '-i', source, '-t', '0.8', '-c:v', 'mjpeg', '-threads', '2', path])
            try: native_frame_diversity(path, 24, log); passed = True
            except RuntimeError: passed = False
            require(passed == expected_pass, 'Video detector failed temporary case: ' + name); results.append(name)
    print('ARSENAL_RECORDING_SELF_TEST_OK: temporary positive stereo/moving and negative dual-mono/silent-channel/rails/black/static cases; no gameplay media read. ' + ', '.join(results))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', choices=STAGES)
    parser.add_argument('--recordings-dir', type=Path)
    delivery = parser.add_mutually_exclusive_group()
    delivery.add_argument('--encode', action='store_true')
    delivery.add_argument('--verify-existing-mp4', action='store_true', help='Recheck a previously encoded delivery, preserving its prior command log')
    parser.add_argument('--log', type=Path, help='Explicit completed native capture log if not stage.log or logs/stage.log')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    try:
        if args.self_test: self_test()
        else:
            require(args.stage is not None and args.recordings_dir is not None, '--stage and --recordings-dir are required')
            run_stage(args)
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('ARSENAL_RECORDING_FAILED: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__': raise SystemExit(main())
