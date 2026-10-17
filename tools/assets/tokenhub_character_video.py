"""Historical TokenHub MiniMax adapter. Recheck provider settings before new jobs."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import time
import requests

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://tokenhub.tencentmaas.com/v1/wand/minimax-video-v2'

def key():
    if os.environ.get('TOKENHUB_API_KEY'):
        return os.environ['TOKENHUB_API_KEY'].strip()
    for line in (ROOT / 'docs/apikeys.txt').read_text(encoding='utf-8-sig').splitlines():
        name, sep, value = line.partition(':')
        if sep and name.strip().lower() == 'tokenhub' and value.strip():
            return value.strip()
    raise RuntimeError('TokenHub credential unavailable')

def save(file, data):
    file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

def request(method, path, payload=None):
    secret = key()
    response = requests.request(method, BASE + path, json=payload,
                                headers={'Authorization': 'Bearer ' + secret}, timeout=(20, 90))
    try:
        data = json.loads(response.content.decode('utf-8').replace(secret, '<REDACTED>'))
    except ValueError:
        data = {'error': {'message': response.text[:1000].replace(secret, '<REDACTED>')}}
    return response.status_code, data

def submit(args, folder):
    image = Path(args.image).resolve()
    prompt = Path(args.prompt).read_text(encoding='utf-8-sig')
    assert args.model == 'minimax-video-h3-max' and args.resolution == '480P' and args.seconds == 5
    uri = 'data:image/png;base64,' + base64.b64encode(image.read_bytes()).decode()
    plan = {'model': args.model, 'resolution': args.resolution, 'duration': args.seconds,
            'input': str(image), 'input_sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
            'prompt': prompt, 'same_first_last_frame': True, 'estimated_cny': args.estimated_cny,
            'price_source': args.price_source}
    # An exclusive marker prevents both duplicate submissions and timeout retries.
    with (folder / 'submission-started.json').open('x', encoding='utf-8') as f:
        json.dump(dict(plan, started_at=time.time()), f, ensure_ascii=False, indent=2)
    payload = {'model': args.model,
               'content': [{'type': 'text', 'text': prompt},
                           {'type': 'image_url', 'image_url': {'url': uri}, 'role': 'first_frame'},
                           {'type': 'image_url', 'image_url': {'url': uri}, 'role': 'last_frame'}],
               'resolution': args.resolution, 'duration': args.seconds,
               'ratio': 'adaptive', 'aigc_watermark': False}
    status, data = request('POST', '/generation', payload)
    save(folder / 'submission-response.json', data)
    print(json.dumps({'http': status, 'task_id': data.get('task_id'), 'error': data.get('error'),
                      'base_resp': data.get('base_resp')}, ensure_ascii=False))

def query(folder):
    source = json.loads((folder / 'submission-response.json').read_text(encoding='utf-8'))
    task_id = source.get('task_id')
    if not task_id:
        raise RuntimeError('No task ID. Inspect rejection; no automatic resubmission.')
    status, data = request('GET', '/tasks/' + task_id)
    save(folder / 'latest-status.json', data)
    task = data.get('task') or {}
    summary = {'http': status, 'task_id': task_id, 'status': task.get('status'),
               'duration': task.get('duration'), 'resolution': task.get('resolution'),
               'usage': data.get('tokenhub_usage'), 'task_usage': task.get('usage'),
               'error': data.get('error') or task.get('error')}
    if task.get('status') == 'succeeded':
        url = (task.get('content') or {}).get('url')
        if not url:
            raise RuntimeError('Successful task missing video URL; inspect response')
        dest = folder / 'source.mp4'
        if not dest.exists():
            result = requests.get(url, timeout=(20, 90))
            result.raise_for_status()
            dest.write_bytes(result.content)
        summary['video'] = str(dest)
        summary['bytes'] = dest.stat().st_size
    print(json.dumps(summary, ensure_ascii=False))

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['submit', 'query'])
    p.add_argument('--output', required=True)
    p.add_argument('--image')
    p.add_argument('--prompt')
    p.add_argument('--model')
    p.add_argument('--resolution')
    p.add_argument('--seconds', type=int)
    p.add_argument('--estimated-cny', type=float)
    p.add_argument('--price-source')
    a = p.parse_args()
    if a.action == 'submit' and (not all([a.image, a.prompt, a.model, a.resolution, a.seconds, a.price_source]) or a.estimated_cny is None or a.estimated_cny < 0):
        p.error('submit requires explicit image, prompt, model, resolution, seconds, estimated-cny and price-source; old batch settings are not a current quote')
    folder = Path(a.output).resolve()
    assert folder.is_relative_to(ROOT / 'Assets/Characters/Trials')
    folder.mkdir(parents=True, exist_ok=True)
    if a.action == 'submit':
        assert a.image and a.prompt
        submit(a, folder)
    else:
        query(folder)
