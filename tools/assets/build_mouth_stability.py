"""Produce head-anchored mouth rendering metadata; never edit animation pixels.

The first accepted idle atlas supplies the closed mouth. Upper-face template
tracking follows head motion, independently of the body's fixed ground pivot.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job', required=True, type=Path)
    parser.add_argument('--reference-texture', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    recipe = json.loads((args.job / 'package-recipe.json').read_text(encoding='utf-8-sig'))
    source = recipe['sources']['motion']
    assert source['root_track'][0][1:] == source['root_track'][-1][1:], 'This recipe requires a fixed body root.'
    files = sorted((args.job / 'originals/12').glob('*.png'))
    first = np.asarray(Image.open(files[0]).convert('RGB'))
    template = cv2.cvtColor(first[180:216, 362:414], cv2.COLOR_RGB2GRAY)
    width, height = recipe['canvas']
    scale = recipe['source_scale']
    reference_rect = [140, 94, 10, 7]
    tracks = []
    for index, path in enumerate(files):
        raw = np.asarray(Image.open(path).convert('RGB'))
        search = cv2.cvtColor(raw[160:244, 344:436], cv2.COLOR_RGB2GRAY)
        _, score, _, point = cv2.minMaxLoc(cv2.matchTemplate(search, template, cv2.TM_CCOEFF_NORMED))
        assert score >= 0.93, f'Face tracking requires review at frame {index}: {score}'
        dx, dy = point[0] + 344 - 362, point[1] + 160 - 180
        rect = [(reference_rect[0] + dx * scale) / width,
                (reference_rect[1] + dy * scale) / height,
                reference_rect[2] / width, reference_rect[3] / height]
        tracks.append({'source_frame': index, 'rect_uv': rect,
                       'raw_head_offset': [dx, dy], 'confidence': round(score, 6)})
    record = {
        'schema': 'return-demo-mouth-stability/v1',
        'method': 'Reuse closed-mouth pixels from original idle atlas; translate only the small rendering region with tracked upper face. No image/video pixels or body pivots rewritten.',
        'reference_texture': args.reference_texture,
        'reference_rect_uv': [reference_rect[0] / width, reference_rect[1] / height,
                              reference_rect[2] / width, reference_rect[3] / height],
        'reference_rect_px': reference_rect,
        'template_raw_rect': [362, 180, 52, 36], 'search_raw_rect': [344, 160, 92, 84],
        'reference_source_frame_sha256': hashlib.sha256(files[0].read_bytes()).hexdigest(),
        'source_frames': tracks,
    }
    args.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'frames': len(tracks), 'minimum_confidence': min(x['confidence'] for x in tracks),
                      'written': str(args.output), 'animation_pixels_modified': False}))


if __name__ == '__main__':
    main()
