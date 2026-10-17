"""Download the pinned Comfy-Org Qwen 2.1 evaluation components."""
import json
import os
from pathlib import Path
from datetime import datetime, timezone
from huggingface_hub import hf_hub_download

ROOT = Path('D:/Work/AI/Image/QwenImage21')
REVISION = 'df94239739eef7205973a145ffa6f441f7b64e84'
FILES = [
    'diffusion_models/qwen_image_2.1_int8_convrot.safetensors',
    'text_encoders/qwen3vl_8b_int8_convrot.safetensors',
    'vae/qwen_image_2.1_vae_bf16.safetensors',
]
os.environ.setdefault('HF_HUB_DOWNLOAD_TIMEOUT', '120')
receipt = {'repo': 'Comfy-Org/Qwen-Image-2.1', 'revision': REVISION,
           'purpose': 'local research/evaluation only', 'files': []}
for name in FILES:
    print('DOWNLOADING', name, flush=True)
    result = hf_hub_download(repo_id=receipt['repo'], filename=name,
                             revision=REVISION, local_dir=ROOT / 'models')
    receipt['files'].append({'file': name, 'path': result, 'bytes': Path(result).stat().st_size})
    receipt['updated_utc'] = datetime.now(timezone.utc).isoformat()
    (ROOT / 'download-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print('COMPLETE', name, Path(result).stat().st_size, flush=True)
