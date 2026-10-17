"""TokenHub HY-3D adapter for the authorized Godot harbor visual trial.

prepare and verify are offline. submit creates at most one accepted job per
candidate directory; a lost response is never silently submitted again.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import urllib.parse
import uuid
import zipfile

from PIL import Image
import requests

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / 'Assets/HarborTrial/v01/Models'
API = 'https://tokenhub.tencentmaas.com/v1/api/3d/'


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def candidate_dir(asset, root=INCOMING):
    root = Path(root).resolve()
    path = (root / asset).resolve()
    if path == root or not path.is_relative_to(root):
        raise ValueError('Candidate must be a child directory of the incoming environment library')
    return path


def prepare(image, pbr=False, face_count=None):
    image = Path(image).resolve()
    if image.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
        raise ValueError('Input must be PNG, JPEG or WebP')
    if not image.is_file() or image.stat().st_size > 6_000_000:
        raise ValueError('Input is missing or exceeds the conservative 6 MB base64 input limit')
    with Image.open(image) as im:
        width, height = im.size
        if not (128 <= width <= 5000 and 128 <= height <= 5000):
            raise ValueError('Each input dimension must be 128–5000 pixels')
        im.verify()
    if face_count is not None and not 3000 <= face_count <= 1500000:
        raise ValueError('face_count must be 3000–1500000 or omitted')
    parameters = dict(model='hy-3d-3.1', generate_type='Normal', enable_pbr=bool(pbr))
    if face_count is not None: parameters['face_count'] = face_count
    return dict(input=str(image), input_sha256=digest(image), input_bytes=image.stat().st_size,
                input_dimensions=[width, height], parameters=parameters, extra_views=0,
                billing='Actual charged credits are not reported by the generation response',
                documentation='https://cloud.tencent.com/document/product/1823/137181')


def get_key():
    if os.environ.get('TOKENHUB_API_KEY'): return os.environ['TOKENHUB_API_KEY'].strip()
    key_file = ROOT / 'docs/apikeys.txt'
    if key_file.is_file():
        for line in key_file.read_text(encoding='utf-8-sig').splitlines():
            name, separator, value = line.partition(':')
            if separator and name.strip().lower() == 'tokenhub' and value.strip(): return value.strip()
    raise RuntimeError('TOKENHUB_API_KEY or the existing docs/apikeys.txt tokenhub entry is required')


def post_json(endpoint, payload, key):
    response = requests.post(API + endpoint, json=payload,
                             headers={'Authorization': 'Bearer ' + key}, timeout=(15, 120))
    # Preserve the provider's useful body even if it uses a non-2xx status.
    content = response.content.decode('utf-8').replace(key, '<REDACTED>')
    data = json.loads(content)
    return response.status_code, data


def job_id(folder):
    candidates = [folder / 'generation-state.json', folder / 'submit-response.json']
    for file in candidates:
        if file.exists():
            data = read_json(file)
            if data.get('id'): return str(data['id'])
    raise RuntimeError('No known job ID. Do not submit again after an uncertain response')


def submit(folder, plan, key, transport=post_json, retry_rejected=False):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    try:
        existing = job_id(folder)
    except RuntimeError:
        existing = None
    if existing: return {'status': 'existing_job', 'id': existing, 'network_submission': False}
    attempts = sorted(folder.glob('attempt-*.started.json'))
    if attempts:
        previous_result = attempts[-1].with_name(attempts[-1].name.replace('.started.', '.result.'))
        if not previous_result.exists():
            raise RuntimeError('Previous submission outcome is uncertain; automatic resubmission is blocked')
        previous = read_json(previous_result)
        if previous.get('state') != 'rejected' or not retry_rejected:
            raise RuntimeError('Only an explicit retry of a confirmed no-job parameter rejection is allowed')
    index = len(attempts) + 1
    started = folder / f'attempt-{index:04d}.started.json'
    record = dict(plan, attempted_at_unix=time.time(), attempt=index)
    # Exclusive creation also prevents two processes from submitting this directory.
    with started.open('x', encoding='utf-8') as stream:
        json.dump(record, stream, ensure_ascii=False, indent=2)
    image = Path(plan['input'])
    if digest(image) != plan['input_sha256']:
        write_json(started.with_name(started.name.replace('.started.', '.result.')),
                   {'state': 'local_input_changed', 'network_submission': False})
        raise RuntimeError('Input changed after preflight; no request was sent')
    payload = dict(plan['parameters'], image_base64=base64.b64encode(image.read_bytes()).decode('ascii'))
    result_path = started.with_name(started.name.replace('.started.', '.result.'))
    try:
        http_status, response = transport('submit', payload, key)
    except Exception as exc:
        # Headers, API keys and base64 input are deliberately absent from the ledger.
        write_json(result_path, {'state': 'uncertain', 'error_type': type(exc).__name__})
        write_json(folder / 'generation-state.json', {'state': 'uncertain', 'attempt': index})
        raise RuntimeError('Submission response is uncertain; preserve the ledger and do not resubmit') from None
    response = json.loads(json.dumps(response).replace(key, '<REDACTED>'))
    if response.get('id'):
        state = 'accepted'
    elif response.get('status') == 'failed' and str(response.get('error', {}).get('code', '')).startswith('InvalidParameter'):
        state = 'rejected'
    else:
        # A quota/auth/service error is retained but does not trigger another request.
        state = 'failed' if response.get('status') == 'failed' else 'uncertain'
    record = {'state': state, 'http_status': http_status, 'response': response, 'attempt': index}
    write_json(result_path, record)
    summary = dict(state=state, id=response.get('id'), status=response.get('status'),
                   request_id=response.get('request_id'), error=response.get('error'), attempt=index)
    write_json(folder / 'generation-state.json', summary)
    if state != 'accepted': raise RuntimeError(json.dumps(summary, ensure_ascii=False))
    return summary


def query(folder, key, transport=post_json):
    identity = job_id(folder)
    http_status, response = transport('query', {'model': 'hy-3d-3.1', 'id': identity}, key)
    response = json.loads(json.dumps(response).replace(key, '<REDACTED>'))
    write_json(folder / 'query-response.json', response)
    return dict(id=identity, http_status=http_status, status=response.get('status'),
                request_id=response.get('request_id'), error=response.get('error'))


def validate_file(path):
    path = Path(path)
    if path.stat().st_size < 16: raise ValueError('Downloaded file is empty or truncated')
    if path.suffix == '.glb':
        with path.open('rb') as stream: magic, version, length = struct.unpack('<4sII', stream.read(12))
        if magic != b'glTF' or version != 2 or length != path.stat().st_size:
            raise ValueError('GLB header or byte length is invalid')
    elif path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None: raise ValueError('OBJ ZIP integrity check failed')
    elif path.suffix == '.png':
        with Image.open(path) as image: image.verify()


def download(folder, fetch=None):
    folder = Path(folder)
    data = read_json(folder / 'query-response.json')
    if data.get('status') not in ('completed', 'success'):
        raise RuntimeError('Provider has not completed the job')
    identity = job_id(folder)
    receipt_file = folder / 'download-receipt.json'
    prior = read_json(receipt_file) if receipt_file.exists() else {'files': []}
    if prior.get('job_id') not in (None, identity): raise RuntimeError('Receipt belongs to another job')
    prior_by_name = {item['file']: item for item in prior['files']}
    targets = {}
    for item in data.get('data', []):
        kind = item.get('type', '').lower()
        if kind in ('glb', 'obj'):
            targets['model.glb' if kind == 'glb' else 'model-obj.zip'] = item['url']
        if item.get('preview_image_url'): targets.setdefault('provider-preview.png', item['preview_image_url'])
    if 'model.glb' not in targets: raise RuntimeError('Completed job did not provide a GLB')
    def fetch_default(url):
        response = requests.get(url, timeout=(15, 180)) # No API authorization on CDN requests.
        response.raise_for_status()
        return response.content
    fetch = fetch or fetch_default
    receipts = []
    for name, url in targets.items():
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != 'https' or parsed.username or parsed.password:
            raise ValueError('Only credential-free HTTPS download URLs are accepted')
        path = folder / name
        if path.exists():
            old = prior_by_name.get(name)
            if not old or digest(path) != old['sha256']:
                raise RuntimeError(f'Refusing to overwrite an unverified original: {name}')
        else:
            temporary = folder / ('incoming-' + uuid.uuid4().hex + '-' + name)
            temporary.write_bytes(fetch(url))
            validate_file(temporary)
            # Hard-link creation is atomic and refuses an existing destination.
            os.link(temporary, path)
            temporary.unlink()
        validate_file(path)
        receipts.append({'file': name, 'bytes': path.stat().st_size, 'sha256': digest(path)})
        # Persist after each file so an interrupted multi-file download is resumable.
        merged = dict(prior_by_name)
        merged.update({item['file']: item for item in receipts})
        write_json(receipt_file, {'job_id': identity, 'files': list(merged.values())})
    return {'id': identity, 'files': receipts}


def verify(folder):
    receipt = read_json(folder / 'download-receipt.json')
    for item in receipt['files']:
        path = (folder / item['file']).resolve()
        if not path.is_relative_to(folder.resolve()): raise ValueError('Receipt path escapes candidate directory')
        validate_file(path)
        if digest(path) != item['sha256']: raise ValueError(f'Original changed: {item["file"]}')
    return {'verified': True, 'id': receipt.get('job_id'), 'files': len(receipt['files'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'submit', 'query', 'download', 'verify'])
    parser.add_argument('--asset', required=True, help='Candidate under Assets/HarborTrial/v01/Models, e.g. warehouse-a')
    parser.add_argument('--root', type=Path, default=INCOMING, help='Versioned candidate root; existing default is retained')
    parser.add_argument('--image', type=Path)
    parser.add_argument('--pbr', action='store_true', help='Optional paid PBR generation; off by default')
    parser.add_argument('--face-count', type=int, help='Optional provider face-count override; omitted by default')
    parser.add_argument('--retry-rejected', action='store_true', help='Permit correction only after an explicit no-job InvalidParameter rejection')
    args = parser.parse_args()
    folder = candidate_dir(args.asset, args.root)
    if args.action in ('prepare', 'submit'):
        if not args.image: parser.error('--image is required for prepare/submit')
        plan = prepare(args.image, args.pbr, args.face_count)
        result = plan if args.action == 'prepare' else submit(folder, plan, get_key(), retry_rejected=args.retry_rejected)
    elif args.action == 'query': result = query(folder, get_key())
    elif args.action == 'download': result = download(folder)
    else: result = verify(folder)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try: main()
    except (ValueError, RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
