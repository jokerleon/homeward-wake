"""Normal-rate review video rendered from the exact published demo atlases."""
import argparse
import json
import math
from functools import lru_cache
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = ['S', 'SE', 'E', 'NE', 'N', 'NW', 'W', 'SW']
MIRRORS = {'SW': 'SE', 'W': 'E', 'NW': 'NE'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--title', required=True)
    parser.add_argument('--mode', default='movement')
    args = parser.parse_args()
    data = json.loads(args.manifest.read_text(encoding='utf-8'))
    args.output.mkdir(parents=True, exist_ok=True)
    sequences = {}
    for direction in DIRECTIONS:
        clips = data['directions'][MIRRORS.get(direction, direction)]['clips']
        if args.mode == 'movement':
            sequence = [('idle', 12), ('move_start', clips['move_start']['frames']),
                        ('move_loop', clips['move_loop']['frames'] * 2),
                        ('move_stop', clips['move_stop']['frames']), ('idle', 12)]
        else:
            sequence = [('idle', 12), (args.mode, clips[args.mode]['frames']), ('idle', 24)]
        sequences[direction] = sequence
    duration = max(sum(count / data['directions'][MIRRORS.get(d, d)]['clips'][name]['fps'] for name, count in seq) for d, seq in sequences.items())
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 17)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 12)

    @lru_cache(maxsize=40)
    def atlas(path):
        return Image.open(ROOT / 'Godot' / path.removeprefix('res://')).convert('RGBA')

    def render(time):
        image = Image.new('RGB', (960, 620), '#243139')
        draw = ImageDraw.Draw(image)
        draw.text((16, 10), args.title + ' · 24fps 原速素材预览', font=font, fill='#f0e1be')
        draw.text((16, 38), '5 个本地 H3 源方向 + 3 个镜像方向；素材检查，非实机验收。', font=small, fill='#a8bcc1')
        for index, direction in enumerate(DIRECTIONS):
            source = MIRRORS.get(direction, direction)
            clips = data['directions'][source]['clips']
            remaining = time; name = 'idle'; frame = 0
            for segment, count in sequences[direction]:
                dt = count / clips[segment]['fps']
                if remaining < dt:
                    name = segment; frame = int(remaining * clips[name]['fps']) % clips[name]['frames']; break
                remaining -= dt
            clip = clips[name]
            x, y, w, h = clip['rects'][frame]['frame']
            sprite = atlas(clip['atlas']).crop((x, y, x + w, y + h))
            if direction in MIRRORS:
                sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            sprite = sprite.resize((240, 240), Image.Resampling.NEAREST)
            left = index % 4 * 240; top = 66 + index // 4 * 274
            image.paste(sprite, (left, top + 18), sprite)
            px = data['pivot_px'][0] / data['canvas'][0] * 240
            if direction in MIRRORS: px = 240 - px
            py = data['pivot_px'][1] / data['canvas'][1] * 240
            draw.line((left + px - 4, top + 18 + py, left + px + 4, top + 18 + py), fill='#e2b46a')
            draw.text((left + 12, top), direction + (' 镜像' if direction in MIRRORS else ''), font=small, fill='#c9dada')
            draw.text((left + 12, top + 251), name + ' ' + str(frame), font=small, fill='#9eb3b9')
        return image

    target = args.output / (args.mode + '.mp4')
    cmd = [shutil.which('ffmpeg'), '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
           '-s', '960x620', '-r', '24', '-i', '-', '-an', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target)]
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for frame in range(math.ceil(duration * 24)):
        process.stdin.write(render(frame / 24).tobytes())
    process.stdin.close(); assert process.wait() == 0
    render(1.5).save(args.output / 'contact.png')
    record = {'title': args.title, 'mode': args.mode, 'fps': 24, 'frames': math.ceil(duration * 24), 'duration': math.ceil(duration * 24) / 24, 'source': str(args.manifest), 'scope': 'Unaltered atlas frames at authored timing; preview layout only, no generated intermediate frames.'}
    (args.output / 'preview.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (args.output / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>' + args.title + '</title><body style="margin:0;background:#243139;color:#eadcbd;font:18px system-ui"><video style="max-width:100%;display:block;margin:auto" controls autoplay muted loop playsinline src="' + target.name + '"></video><p style="text-align:center">' + args.title + ' · 1× / 24fps · 本地 H3 视频拆帧，镜像方向在画面标注。</p></body>', encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
