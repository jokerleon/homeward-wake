"""Suggest source loop boundaries for human visual inspection; no adoption."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from key_local_h3_image import key_rgba


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--max-span', type=int, default=48)
    parser.add_argument('--first-begin', type=int, default=12)
    args = parser.parse_args()
    sheet = Image.new('RGB', (720, 196 * len(args.folders)), '#263239')
    draw = ImageDraw.Draw(sheet)
    records = []
    for row, folder in enumerate(args.folders):
        files = sorted((folder / 'originals/12').glob('*.png'))
        frames = [key_rgba(Image.open(file)) for file in files]
        arrays = [np.array(frame.resize((64, 64)), dtype=np.float32) / 255 for frame in frames]
        features = [np.concatenate([a[:, :, :3] * a[:, :, 3:], a[:, :, 3:]], axis=2) for a in arrays]
        candidates = []
        for begin in range(args.first_begin, 50):
            for end in range(begin + 20, min(begin + args.max_span + 1, len(files) - 8)):
                difference = float(np.square(features[begin] - features[end]).mean())
                candidates.append((difference, begin, end))
        candidates.sort()
        chosen = []
        for distance, begin, end in candidates:
            if any(abs(begin - a['begin']) < 5 and abs(end - a['end_exclusive']) < 5 for a in chosen):
                continue
            chosen.append({'begin': begin, 'end_exclusive': end, 'diagnostic_distance': round(distance, 6)})
            if len(chosen) == 2:
                break
        records.append({'folder': folder.as_posix(), 'candidates': chosen, 'note': 'Numerical matching suggests a seam, not animation quality.'})
        for choice, candidate in enumerate(chosen):
            for sample, index in enumerate([candidate['begin'], candidate['end_exclusive'] - 1]):
                image = frames[index].copy(); image.thumbnail((180, 180))
                x = (choice * 2 + sample) * 180; y = row * 196 + 16
                sheet.paste(image, (x, y), image)
                draw.text((x + 3, y + 164), str(index), fill='#e0bc75')
        draw.text((3, row * 196 + 2), folder.name, fill='#e5eeef')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    args.output.with_suffix('.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(records))


if __name__ == '__main__':
    main()
