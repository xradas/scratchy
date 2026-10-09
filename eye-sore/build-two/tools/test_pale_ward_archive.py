"""Reproducible synthetic fixtures for the independent Pale Ward archive verifier.

Run directly with --report PATH or through unittest discovery. No engine, export,
existing package, network, or Git checkout is required.
"""
import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('audit', ROOT / 'tools/verify_pale_ward_archive.py')
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)
sha = lambda value: hashlib.sha256(value).hexdigest()
json_bytes = lambda value: (json.dumps(value) + '\n').encode()
EXE = 'fixture.x86_64'
commit = '0123456789abcdef0123456789abcdef01234567'
# Synthetic component records intentionally test structure without an installed engine.
ENGINE_LICENSE = '''Copyright (c) 2026 Fixture copyright holders.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the \"Software\"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''
COMPONENTS = [
    {'name': name, 'parts': [{'copyright': ['2026 Fixture authors'], 'files': ['fixture/*'], 'license': 'Expat'}]}
    for name in ('Godot Engine', 'Fixture dependency')
]
ENGINE_NOTICES = ('Bundled Godot component copyright records\n\n'
                  + json.dumps(COMPONENTS) + '\n\nExpat\n' + ENGINE_LICENSE).encode()


def initial():
    p = {
        EXE: b'Fixture executable; not runnable',
        'README.txt': b'Fixture instructions. Human acceptance pending.\n',
        'AUDIO_CREDITS.md': (ROOT / 'assets/audio/CREDITS.md').read_bytes(),
        'VISUAL_CREDITS.md': (ROOT / 'assets/VISUAL_CREDITS.md').read_bytes(),
        'smoke.log': b'Godot Engine v4.7.2\nOpenGL API 3.3 - Compatibility - Using Device: Fixture\nGORE_EXPORT_SMOKE_OK: fixture\nFOUNDATION_SMOKE_OK: fixture\n',
        'export.log': b'Fixture export successful\n',
        'licenses.log': b'ENGINE_LICENSES_OK: fixture\n',
    }
    p['GODOT_LICENSE.txt'] = ENGINE_LICENSE.encode()
    p['GODOT_THIRD_PARTY_NOTICES.txt'] = ENGINE_NOTICES
    for name in (audit.MATERIAL, audit.SIGN):
        p['provenance/' + name] = (ROOT / name).read_bytes()
    record = {'bytes': 1, 'sha256': 'a' * 64}
    b = {'source_commit': commit, 'source_head': commit, 'source_git_status': 'fixture',
         'engine_binary': record.copy(), 'linux_release_template': record.copy(),
         'executable': {'path': EXE, 'sha256': sha(p[EXE]), 'bytes': len(p[EXE]), 'mode': '0755', 'pck': 'embedded'},
         'source_checksums': 'SOURCE_SHA256SUMS',
         'verification': {'native_export_smoke': 'smoke.log', 'working_directory': '/tmp', 'exit_code': 0,
                          'success_markers': list(audit.MARKERS)},
         'known_issues': ['Fixture archive, not a release or acceptance claim.']}
    return p, b


def finish(p, b):
    source = {audit.BOARD: sha((ROOT / audit.BOARD).read_bytes()),
              'assets/audio/CREDITS.md': sha(p.get('AUDIO_CREDITS.md', b'')),
              'assets/VISUAL_CREDITS.md': sha(p.get('VISUAL_CREDITS.md', b''))}
    source.update({k.removeprefix('provenance/'): sha(v) for k,v in p.items() if k.startswith('provenance/')})
    p['SOURCE_SHA256SUMS'] = ''.join(f'{v}  {k}\n' for k,v in sorted(source.items())).encode()
    b['source_tree_sha256'] = sha(json.dumps(source, sort_keys=True).encode())
    p['BUILD.json'] = json_bytes(b)
    p['SHA256SUMS'] = ''.join(f'{sha(v)}  {k}\n' for k,v in sorted(p.items())).encode()


def write(path, p, special=None, mode=0o755):
    with tarfile.open(path, 'w:gz') as tar:
        for name, value in p.items():
            m = tarfile.TarInfo(name); m.size = len(value); m.mode = mode if name == EXE else 0o644
            tar.addfile(m, io.BytesIO(value))
        if special:
            name, kind = special
            m = tarfile.TarInfo(name); m.mode = 0o644
            if kind == 'link':
                m.type = tarfile.SYMTYPE; m.linkname = '/etc/passwd'
            tar.addfile(m)


class Fixtures(unittest.TestCase):
    def test_good_archive_and_report(self):
        with tempfile.TemporaryDirectory() as d:
            p,b = initial(); finish(p,b); archive=Path(d)/'good.tar.gz'; write(archive,p)
            result=audit.verify(archive)
            self.assertEqual(result['source_commit'],commit)
            self.assertFalse(result['smoke_evidence']['rerun_by_verifier'])
            report=Path(d)/'good.json'
            proc=subprocess.run(['python3', str(ROOT/'tools/verify_pale_ward_archive.py'),str(archive),'--report',str(report)],capture_output=True,text=True)
            self.assertEqual(proc.returncode,0,proc.stdout+proc.stderr)
            self.assertEqual(json.loads(report.read_text())['status'],'passed')

    def test_semantic_failure_fixtures(self):
        cases = {
            'build executable hash': (lambda p,b: b['executable'].update(sha256='0'*64), 'BUILD executable hash mismatch'),
            'build executable size': (lambda p,b: b['executable'].update(bytes=1), 'BUILD executable size mismatch'),
            'zero commit': (lambda p,b: b.update(source_commit='0'*40), 'full nonzero'),
            'head mismatch': (lambda p,b: b.update(source_head='a'*40), 'differs from source_head'),
            'smoke wrong cwd': (lambda p,b: b['verification'].update(working_directory='/home/fixture'), '/tmp'),
            'smoke nonzero': (lambda p,b: b['verification'].update(exit_code=1), 'exit 0'),
            'smoke missing marker': (lambda p,b: p.update({'smoke.log': p['smoke.log'].replace(b'GORE_EXPORT_SMOKE_OK:',b'NO:')}), 'success marker missing'),
            'smoke error': (lambda p,b: p.update({'smoke.log':p['smoke.log']+b'ERROR: fixture\n'}), 'errors/warnings/failure'),
            'headless evidence': (lambda p,b: p.update({'smoke.log':p['smoke.log'].replace(b'OpenGL API',b'Headless API')}), 'graphics-device evidence'),
            'export error': (lambda p,b:p.update({'export.log':b'SCRIPT ERROR: fixture'}), 'Export log'),
            'missing audio': (lambda p,b:p.pop('AUDIO_CREDITS.md'), 'missing: AUDIO_CREDITS.md'),
            'missing visual': (lambda p,b:p.pop('VISUAL_CREDITS.md'), 'missing: VISUAL_CREDITS.md'),
            'missing engine component notices': (lambda p,b:p.pop('GODOT_THIRD_PARTY_NOTICES.txt'), 'missing: GODOT_THIRD_PARTY_NOTICES.txt'),
            'truncated engine license': (lambda p,b:p.update({'GODOT_LICENSE.txt':b'Godot Engine'}), 'missing clause'),
            'missing engine component license': (lambda p,b:p.update({'GODOT_THIRD_PARTY_NOTICES.txt':p['GODOT_THIRD_PARTY_NOTICES.txt'].replace(b'\nExpat\n',b'\nMISSING\n')}), 'Component license text missing'),
            'missing material manifest': (lambda p,b:p.pop('provenance/'+audit.MATERIAL), 'missing: provenance/'+audit.MATERIAL),
            'missing sign manifest': (lambda p,b:p.pop('provenance/'+audit.SIGN), 'missing: provenance/'+audit.SIGN),
            'wrong material original hash': (lambda p,b: p.update({'provenance/'+audit.MATERIAL:json_bytes({**json.loads(p['provenance/'+audit.MATERIAL]),'source_sha256':'0'*64})}), 'Material original/runtime board hashes'),
            'wrong sign board path': (lambda p,b: p.update({'provenance/'+audit.SIGN:json_bytes({**json.loads(p['provenance/'+audit.SIGN]),'source':'res://wrong.png'})}), 'Sign source path/hash'),
        }
        for name,(mutate,error) in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as d:
                p,b=initial(); mutate(p,b); finish(p,b); archive=Path(d)/'bad.tar.gz'; write(archive,p)
                with self.assertRaisesRegex(audit.AuditError,error):audit.verify(archive)

    def test_container_integrity_failures(self):
        cases = ('duplicate', 'traversal', 'absolute', 'symlink', 'alias', 'unsafe mode', 'nonexecutable mode', 'coverage omission', 'coverage extra', 'hash tamper', 'duplicate checksum', 'self checksum', 'source digest', 'source manifest digest')
        for name in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as d:
                p,b=initial(); finish(p,b); special=None; mode=0o755
                if name=='duplicate':special=(EXE,'file')
                if name=='traversal':special=('../outside','file')
                if name=='absolute':special=('/tmp/outside','file')
                if name=='symlink':special=('link','link')
                if name=='alias':special=('./alias','file')
                if name=='unsafe mode':mode=0o4755
                if name=='nonexecutable mode':mode=0o644
                if name=='coverage omission':p['unexpected.bin']=b'unlisted payload'
                if name=='coverage extra':p['SHA256SUMS']+=(b'0'*64)+b'  absent.bin\n'
                if name=='hash tamper':p[EXE]=b'modified executable'
                if name=='duplicate checksum':p['SHA256SUMS']+=p['SHA256SUMS'].splitlines(keepends=True)[0]
                if name=='self checksum':p['SHA256SUMS']+=(b'0'*64)+b'  SHA256SUMS\n'
                if name=='source digest':
                    b['source_tree_sha256']='0'*64;p['BUILD.json']=json_bytes(b)
                    p['SHA256SUMS']=''.join(f'{sha(v)}  {k}\n' for k,v in sorted(p.items()) if k!='SHA256SUMS').encode()
                if name=='source manifest digest':
                    source=audit.checksums(p['SOURCE_SHA256SUMS'].decode(),'fixture');source[audit.MATERIAL]='0'*64
                    p['SOURCE_SHA256SUMS']=''.join(f'{v}  {k}\n' for k,v in sorted(source.items())).encode()
                    b['source_tree_sha256']=sha(json.dumps(source,sort_keys=True).encode());p['BUILD.json']=json_bytes(b)
                    p['SHA256SUMS']=''.join(f'{sha(v)}  {k}\n' for k,v in sorted(p.items()) if k!='SHA256SUMS').encode()
                archive=Path(d)/'bad.tar.gz';write(archive,p,special,mode)
                with self.assertRaises(audit.AuditError):audit.verify(archive)

    def test_missing_archive_fails_and_writes_report(self):
        with tempfile.TemporaryDirectory() as d:
            archive=Path(d)/'absent.tar.gz';report=Path(d)/'missing.json'
            proc=subprocess.run(['python3',str(ROOT/'tools/verify_pale_ward_archive.py'),str(archive),'--report',str(report)],capture_output=True,text=True)
            self.assertEqual(proc.returncode,1)
            result=json.loads(report.read_text());self.assertEqual(result['status'],'failed');self.assertNotIn('source_commit',result)
            self.assertIn('No acceptance claim',result['scope'])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Write synthetic-test results as JSON')
    args, remaining = parser.parse_known_args()
    program = unittest.main(argv=[__file__, *remaining], verbosity=2, exit=False)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps({
            'status': 'passed' if program.result.wasSuccessful() else 'failed',
            'tests_run': program.result.testsRun,
            'rejection_variants': 33,
            'failures': len(program.result.failures),
            'errors': len(program.result.errors),
            'scope': 'Synthetic archive fixtures and CLI behavior only; no real release archive or human acceptance verified.'
        }, indent=2) + '\n', encoding='utf-8')
    raise SystemExit(0 if program.result.wasSuccessful() else 1)

