"""Resumable ranged download from the official Comfy-Org ModelScope mirror."""
import concurrent.futures
import hashlib
import json
import shutil
import time
from pathlib import Path
import requests

ROOT = Path('D:/Work/AI/Image/QwenImage21')
BASE = 'https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/'
FILES = [
    ('diffusion_models/qwen_image_2.1_int8_convrot.safetensors', 7256783064, 'cb74113cb03faecd79611b01fd7fd642f0aa60d6f0b95086abee214d75eaa57d'),
    ('text_encoders/qwen3vl_8b_int8_convrot.safetensors', 9350798360, '8bfd0f6e12abf2d2d697ecc888e5e90b0d6741d6708f05799f53afa560452e8f'),
    ('vae/qwen_image_2.1_vae_bf16.safetensors', 675509688, 'bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9'),
]
CHUNK = 16 * 1024 * 1024

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda: f.read(8 * 1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()

receipt = {'source': BASE, 'purpose': 'local research/evaluation', 'files': []}
for name, size, sha in FILES:
    target = ROOT / 'models' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix('.download-part')
    progress = target.with_suffix('.download-progress.json')
    count = (size + CHUNK - 1) // CHUNK
    completed = set(json.loads(progress.read_text()) if progress.exists() else [])
    if target.exists() and digest(target) == sha:
        print('ALREADY_VERIFIED', name, flush=True)
        continue
    if not partial.exists():
        candidates = list((ROOT / 'models/.cache/huggingface/download/diffusion_models').glob('*.xet-paused')) if name.startswith('diffusion_models/') else []
        if candidates and candidates[0].stat().st_size == size:
            shutil.copyfile(candidates[0], partial)
            zero = bytes(65536)
            with partial.open('rb') as f:
                for i in range(count):
                    data = f.read(CHUNK)
                    if not any(data[j:j+65536] == zero for j in range(0, len(data)-65535, 65536)):
                        completed.add(i)
            print('RECOVERED_CANDIDATE_CHUNKS', len(completed), '/', count, flush=True)
        else:
            with partial.open('wb') as f:
                f.truncate(size)
    def fetch(index):
        start = index * CHUNK
        end = min(size, start + CHUNK) - 1
        expected = f'bytes {start}-{end}/{size}'
        for attempt in range(3):
            try:
                response = requests.get(BASE + name, headers={'Range': f'bytes={start}-{end}'}, timeout=(20, 60))
                response.raise_for_status()
                if response.headers.get('Content-Range') != expected or len(response.content) != end-start+1:
                    raise RuntimeError('Invalid range response')
                with partial.open('r+b') as f:
                    f.seek(start)
                    f.write(response.content)
                return index
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(2)
    for verify_round in range(2):
        missing = [i for i in range(count) if i not in completed]
        print('FETCH', name, len(missing), 'chunks', flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            for index in pool.map(fetch, missing):
                completed.add(index)
                progress.write_text(json.dumps(sorted(completed)))
                if len(completed) % 12 == 0 or len(completed) == count:
                    print('PROGRESS', name, f'{len(completed)}/{count}', flush=True)
        actual = digest(partial)
        if actual == sha:
            partial.replace(target)
            receipt['files'].append({'name': name, 'bytes': size, 'sha256': actual, 'verified': True})
            (ROOT / 'download-receipt-ranges.json').write_text(json.dumps(receipt, indent=2))
            print('VERIFIED', name, flush=True)
            break
        print('HASH_MISMATCH: re-fetch all chunks once', name, flush=True)
        completed.clear()
        progress.write_text('[]')
    else:
        raise RuntimeError('Hash verification failed twice: ' + name)
