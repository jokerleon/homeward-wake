"""Create a review-only contact sheet from immutable H3 decoded frames."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from key_local_h3_image import key_rgba


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--samples', type=int, default=9)
    parser.add_argument('--columns', type=int, default=0)
    parser.add_argument('--tile', type=int, default=180)
    args = parser.parse_args()
    tile = args.tile
    columns = args.columns or args.samples
    rows = math.ceil(args.samples / columns)
    sheet = Image.new('RGB', (tile * columns, (tile + 36) * len(args.folders) * rows), '#263239')
    draw = ImageDraw.Draw(sheet)
    report = []
    for row, folder in enumerate(args.folders):
        files = sorted((folder / 'originals/12').glob('*.png'))
        assert files, folder
        indices = np.linspace(0, len(files) - 1, args.samples).round().astype(int)
        measurements = []
        for column, index in enumerate(indices):
            keyed = key_rgba(Image.open(files[index]))
            alpha = np.asarray(keyed)[:, :, 3]
            ys, xs = np.where(alpha > 32)
            box = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
            # Feet are measured for review; these values never recenter animation.
            low_y, low_x = np.where((alpha > 64) & (np.indices(alpha.shape)[0] > box[3] - 25))
            foot_center = round(float((low_x.min() + low_x.max()) / 2), 1)
            measurements.append({'frame': int(index), 'bbox': box, 'foot_span_center': foot_center})
            keyed.thumbnail((tile, tile), Image.Resampling.LANCZOS)
            x = (column % columns) * tile
            y = (row * rows + column // columns) * (tile + 36)
            sheet.paste(keyed, (x, y + 20), keyed)
            draw.text((x + 4, y + 20 + tile), str(index), fill='#dcb970')
        draw.text((4, row * rows * (tile + 36) + 3), folder.name, fill='#e7efef')
        report.append({'folder': str(folder), 'frames': len(files), 'samples': measurements})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'sheet': str(args.output), 'review': report}))


if __name__ == '__main__':
    main()
