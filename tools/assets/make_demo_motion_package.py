"""Prepare an explicit source-frame recipe using one fixed first-frame foot pivot."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from key_local_h3_image import key_rgba

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job', required=True, type=Path)
    parser.add_argument('--character', required=True)
    parser.add_argument('--direction', required=True)
    parser.add_argument('--action', default='move')
    parser.add_argument('--range', type=int, nargs=2)
    parser.add_argument('--loop', type=int, nargs=2)
    parser.add_argument('--start', type=int, default=6)
    parser.add_argument('--stop', type=int, nargs=2, default=[78, 90])
    parser.add_argument('--scale', type=float, default=0.5)
    parser.add_argument('--root', type=float, nargs=2)
    parser.add_argument('--canvas', type=int, nargs=2, default=[384,384])
    parser.add_argument('--pivot', type=float, nargs=2, default=[192,324])
    args = parser.parse_args()
    folder = args.job.resolve()
    assert folder.is_relative_to(ROOT / 'Assets/Characters/Working')
    sources = sorted((folder / 'originals/12').glob('*.png'))
    first = np.asarray(key_rgba(Image.open(sources[0])))[:, :, 3]
    ys, xs = np.where(first > 64)
    low_y, low_x = np.where((first > 64) & (np.indices(first.shape)[0] >= ys.max() - (ys.max() - ys.min()) * 0.2))
    root = args.root or [float((low_x.min() + low_x.max()) / 2), float(ys.max())]
    relative = folder.relative_to(ROOT).as_posix()
    if args.action == 'move':
        assert args.loop, 'Movement needs explicitly reviewed loop boundaries.'
        clips = {
            'idle': {'source': 'motion', 'range': [0, 1], 'loop': True},
            'move_start': {'source': 'motion', 'range': [args.start, args.loop[0]], 'loop': False},
            'move_loop': {'source': 'motion', 'range': args.loop, 'loop': True},
            'move_stop': {'source': 'motion', 'range': args.stop, 'loop': False},
        }
    else:
        assert args.range, 'Action needs an explicitly reviewed source-frame range.'
        clips = {'idle': {'source': 'motion', 'range': [0, 1], 'loop': True},
                 args.action: {'source': 'motion', 'range': args.range, 'loop': False}}
    recipe = {
        'character': args.character, 'direction': args.direction, 'stage': 'candidate',
        'output': relative + '/pack', 'canvas': args.canvas, 'pivot': args.pivot,
        'fps': 24, 'source_scale': args.scale, 'key_method': 'local_h3_green',
        'root_track_note': 'One fixed first-frame boot-area center and sole baseline; no per-frame bounding-box centering. Actual body bob and lowering are retained.',
        'sources': {'motion': {'file': relative + '/originals/11/source_00001.mp4',
                               'frames_dir': relative + '/originals/12',
                               'root_track': [[0, *root], [len(sources) - 1, *root]]}},
        'clips': clips,
        'transitions': {
            'idle_to_move_start': {'mode': 'immediate', 'enter_frame': 0, 'max_wait_frames': 0},
            'move_start_to_move_loop': {'enter_frame': 0},
            'move_loop_to_move_stop': {'exit_before_frame': 0, 'max_wait_frames': 0},
            'move_stop_to_idle': {'enter_frame': 0},
        },
    }
    if args.action == 'move' and args.stop == [0, 1]:
        recipe['clips']['move_stop']['review_note'] = 'Immediate return to ready hold; source did not contain a usable settling phase. Gameplay movement stops immediately.'
    (folder / 'package-recipe.json').write_text(json.dumps(recipe, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'recipe': relative + '/package-recipe.json', 'fixed_root': root, 'clips': {k: v['range'] for k, v in recipe['clips'].items()}}))


if __name__ == '__main__':
    main()
