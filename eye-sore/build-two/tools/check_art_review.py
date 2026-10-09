#!/usr/bin/env python3
"""Read-only, stdlib checks of review provenance and supplied direction data."""
import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import struct
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
CURRENT = ('containment-entry', 'containment-stairs', 'bio-wing', 'operating-room', 'rear-lab', 'exit-gallery')
OLDER = ('before-entry', 'before-stairs')
BOARDS = {f'concepts/visual-v2/{name}/board.png' for name in ('corrupted-biotech', 'civic-invasion', 'occult-fortress')}
REFERENCES = {f'concepts/visual-v2/corrupted-biotech/{name}.png' for name in ('scene', 'scene_pixel_preview')}


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.ids, self.classes, self.links, self.refs, self.options, self.text = set(), set(), [], [], {}, []
        self.duplicates, self.select = [], None
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                self.duplicates.append(attrs['id'])
            self.ids.add(attrs['id'])
        self.classes.update(attrs.get('class', '').split())
        for key in ('src', 'href', 'poster'):
            if key in attrs:
                self.links.append(attrs[key])
        for key in ('for', 'aria-labelledby', 'aria-describedby'):
            self.refs.extend(attrs.get(key, '').split())
        if tag == 'select':
            self.select = attrs.get('id')
            self.options[self.select] = []
        elif tag == 'option' and self.select:
            self.options[self.select].append(attrs.get('value'))

    def handle_endtag(self, tag):
        if tag == 'select':
            self.select = None

    def handle_data(self, data):
        self.text.append(data)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def metadata(data):
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise ValueError('invalid PNG header')
    width, height = struct.unpack('>II', data[16:24])
    return dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), width=width, height=height)


def audit(root, html_override=None):
    checks = []
    def check(name, ok, detail=''):
        checks.append(dict(check=name, passed=bool(ok), detail=detail))
    def path_exists(relative):
        candidate = (root / relative).resolve()
        return candidate.is_relative_to(root.resolve()) and candidate.is_file()
    def local_link(link, base):
        parsed = urlsplit(link)
        if parsed.scheme or parsed.netloc:
            check('local review resource', False, link)
            return
        if parsed.path:
            relative = str((base / unquote(parsed.path)).relative_to(root))
            check('resource exists', path_exists(relative), relative)
        if parsed.fragment:
            check('fragment ID exists', parsed.fragment in page.ids, link)

    tracked = git(root, 'ls-files', 'concepts').decode().splitlines()
    protected = [name for name in tracked if Path(name).name in ('board.png', 'scene.png', 'scene_pixel_preview.png', 'scene_preview_native.png')]
    protected.append('concepts/index.html')
    check('original references registered', len(protected) >= 13, str(len(protected)))
    for name in protected:
        data = git(root, 'show', f'HEAD:./{name}')
        check('original preserved against HEAD', path_exists(name) and (root / name).read_bytes() == data, name)

    html = html_override if html_override is not None else (root / 'concepts/grit-review.html').read_text()
    css = (root / 'concepts/grit-review.css').read_text()
    js = (root / 'concepts/grit-review.js').read_text()
    page = Page(html)
    check('unique HTML IDs', not page.duplicates, ', '.join(page.duplicates))
    for reference in page.refs:
        check('HTML selector ID exists', reference in page.ids, reference)
    for selector in re.findall(r'getElementById\([\'"]([^\'"]+)[\'"]\)', js):
        check('JS selector ID exists', selector in page.ids, selector)
    for selectors in re.findall(r'([^{}]+)\{', css):
        for selector in re.findall(r'(?<![\w-])[.#]([a-zA-Z_][\w-]*)', selectors):
            check('CSS selector exists', selector in page.ids or selector in page.classes, selector)
    for link in page.links:
        local_link(link, root / 'concepts')
    for link in re.findall(r'url\([\'"]?([^\)\'\"]+)', css):
        local_link(link.strip(), root / 'concepts')
    # Resolve this page's two dynamic source templates from the real option values.
    templates = re.findall(r'const source\s*=\s*`([^`]+)`', js)
    expected_templates = {'visual-v2/corrupted-biotech/${pixelPreview ? "scene_pixel_preview" : "scene"}.png', 'grit-review-assets/${option.value}.png'}
    check('audited dynamic source templates', set(templates) == expected_templates, repr(templates))
    check('target options', set(page.options.get('target-view', [])) == {'scene', 'scene_pixel_preview'})
    check('current options', tuple(page.options.get('current-view', [])) == CURRENT)
    for name in page.options.get('target-view', []):
        local_link(f'visual-v2/corrupted-biotech/{name}.png', root / 'concepts')
    for name in page.options.get('current-view', []):
        local_link(f'grit-review-assets/{name}.png', root / 'concepts')
    text = ' '.join(page.text).lower()
    for label in ('concept artwork', 'actual current game', 'older game', 'do not establish a visual match or approval', 'no acceptance claim'):
        check('honest review label', label in text, label)
    # Assertions concern game acceptance, not the approved reference or byte identity.
    for sentence in re.split(r'[.!?\n]+', text):
        affirmative = re.search(r'\b(game|gameplay|implementation|captures?)\b.{0,70}\b(accepted|matched|exact whole|exact reproduction|visually approved)\b', sentence)
        negative = re.search(r'\b(no|not|neither|pending|without|does not|do not)\b', sentence)
        check('no affirmative game acceptance claim', not affirmative or bool(negative), sentence.strip() if affirmative else '')

    manifest = json.loads((root / 'concepts/grit-review-assets/manifest.json').read_text())
    captures = manifest.get('captures', [])
    check('exactly eight capture records', len(captures) == 8)
    check('exact expected capture names', {item.get('source') for item in captures} == {f'verification/grit/{name}.png' for name in CURRENT + OLDER})
    for item in captures:
        source, copy = item.get('source', ''), item.get('copy', '')
        name = Path(source).stem
        check('capture copy destination', copy == f'concepts/grit-review-assets/{name}.png', copy)
        check('capture status', item.get('status') == ('actual current game' if name in CURRENT else 'older game'), name)
        if not path_exists(source) or not path_exists(copy):
            check('capture source and copy exist', False, f'{source} / {copy}')
            continue
        data = (root / source).read_bytes()
        check('unchanged capture PNG bytes', data == (root / copy).read_bytes(), name)
        actual = metadata(data)
        check('capture manifest metadata', all(item.get(key) == value for key, value in actual.items()), name)
    refs = manifest.get('approved_references', {})
    check('manifest original references', set(refs) == REFERENCES)
    for name, item in refs.items():
        check('manifest reference exists', path_exists(name), name)
        if path_exists(name):
            check('reference manifest metadata', item == metadata((root / name).read_bytes()), name)

    direction = json.loads((root / 'docs/production-direction.json').read_text())
    contract, story, team = (direction.get(key, {}) for key in ('visual_contract', 'story_draft', 'team'))
    check('current approved board path', contract.get('reference') == 'concepts/visual-v2/corrupted-biotech/board.png')
    check('current approved preview path', contract.get('reference_scene') == 'concepts/visual-v2/corrupted-biotech/scene_pixel_preview.png')
    for key in ('reference', 'reference_scene'):
        check('contract reference exists', path_exists(contract.get(key, '')), contract.get(key, ''))
    check('supplied story remains a draft', 'coordinator draft' in story.get('status', '').lower() and 'no campaign is implemented' in story.get('status', '').lower())
    check('supplied story fields present', all(isinstance(story.get(key), str) and story[key].strip() for key in ('premise', 'player_objective')))
    chapters = story.get('chapter_order', [])
    check('supplied chapter order', [chapter.get('id') for chapter in chapters] == ['arrival', 'occupied_line', 'pale_ward', 'ash_citadel', 'source'])
    check('all three approved chapter boards', {chapter['reference'] for chapter in chapters if 'reference' in chapter} == BOARDS)
    for name in BOARDS:
        check('approved board file exists', path_exists(name), name)
    tasks = team.get('tasks', [])
    check('21 specialist roles', team.get('specialist_count') == len(tasks) == 21)
    check('distinct specialist IDs', {task[0] for task in tasks} == {f'p{n:02}' for n in range(1, 22)})
    check('distinct specialist responsibilities', len({task[1] for task in tasks}) == 21)
    check('maximum three concurrent workers', isinstance(team.get('concurrent_workers'), int) and 1 <= team['concurrent_workers'] <= 3)
    return dict(passed=all(item['passed'] for item in checks), checks=checks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--self-test', action='store_true', help='Inject one missing resource in memory and require detection.')
    parser.add_argument('--test-missing-path', action='store_true', help='Negative fixture: audit an in-memory missing image; exits 1.')
    args = parser.parse_args()
    try:
        override = None
        if args.test_missing_path:
            override = (args.root / 'concepts/grit-review.html').read_text() + '<img src="grit-review-assets/p16-intentionally-missing.png">'
        report = audit(args.root, override)
        if args.test_missing_path:
            report['fixture'] = 'Missing asset added to HTML in memory only; source files unchanged.'
        if args.self_test:
            html = (args.root / 'concepts/grit-review.html').read_text()
            probe = audit(args.root, html + '<img src="grit-review-assets/p16-intentionally-missing.png">')
            caught = any(not item['passed'] and item['detail'] == 'concepts/grit-review-assets/p16-intentionally-missing.png' for item in probe['checks'])
            report['negative_missing_path_test'] = dict(passed=caught, fixture='in-memory HTML only', injected_audit_passed=probe['passed'])
            report['passed'] = report['passed'] and caught and not probe['passed']
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        report = dict(passed=False, error=str(error))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    failures = [item for item in report.get('checks', []) if not item['passed']]
    print(json.dumps(dict(passed=report['passed'], checks=len(report.get('checks', [])), failures=failures, error=report.get('error'), negative_missing_path_test=report.get('negative_missing_path_test')), indent=2))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
