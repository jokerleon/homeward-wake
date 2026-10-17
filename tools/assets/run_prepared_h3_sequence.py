"""Run an explicit, bounded list of already prepared local H3 jobs serially.

Never retries submission, edits a workflow, or adds a job to an occupied queue.
Each successful job is collected before the next is submitted. Original receipts
remain the authority after an interruption; ambiguous markers stop the sequence.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / 'tools/assets/local_h3_assets.py'


def invoke(action, recipe):
    result = subprocess.run([sys.executable, str(ADAPTER), action, str(recipe)],
                            cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout.strip().splitlines()[-1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('recipes', nargs='+', type=Path)
    args = parser.parse_args()
    assert 1 <= len(args.recipes) <= 8, 'Specify at most eight reviewed prepared jobs.'
    assert len(set(map(str, args.recipes))) == len(args.recipes)
    for path in args.recipes:
        recipe_path = path.resolve()
        assert recipe_path.is_relative_to(ROOT / 'Assets/Characters/Working')
        recipe = json.loads(recipe_path.read_text(encoding='utf-8-sig'))
        folder = ROOT / recipe['output']
        assert recipe['kind'] == 'motion' and recipe['endpoint'] == 'http://127.0.0.1:8196'
        assert (folder / 'workflow-api.json').is_file(), 'Prepare and inspect before executing.'
        if not (folder / 'submission.json').exists():
            assert not (folder / 'submission-started.json').exists(), 'Ambiguous submission; do not retry.'
            receipt = invoke('submit', recipe_path)
            print(json.dumps({'id': recipe['id'], 'submitted': receipt}), flush=True)
        deadline = time.monotonic() + 1800
        while True:
            result = invoke('collect', recipe_path)
            if result.get('completed') and result.get('status') == 'success':
                print(json.dumps({'id': recipe['id'], 'collected': True,
                                  'prompt_id': result['prompt_id'], 'seconds': result.get('seconds')}), flush=True)
                break
            if result.get('errors') or result.get('status') in ['error', 'failed']:
                raise RuntimeError(json.dumps(result))
            assert time.monotonic() < deadline, 'Timed out; keep receipt and inspect this job, never resubmit.'
            time.sleep(8)


if __name__ == '__main__':
    main()
