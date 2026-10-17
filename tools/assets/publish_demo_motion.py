"""Copy explicitly reviewed Working clips into demo-only runtime manifests."""
import argparse
import copy
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', required=True, type=Path)
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text(encoding='utf-8'))
    output = ROOT / 'Godot/assets/demo/characters' / spec['key'] / spec['state']
    assert output.resolve().is_relative_to(ROOT / 'Godot/assets/demo/characters')
    output.mkdir(parents=True, exist_ok=True)
    scale = float(spec.get('runtime_scale', 0.5))
    manifest = {
        'schema': 'return-demo-motion-set/v1', 'character': spec['character'],
        'state': spec['state'], 'default_direction': spec.get('default_direction', 'E'), 'canvas': [round(x * scale) for x in spec['canvas']],
        'pivot_px': [x * scale for x in spec['pivot_px']],
        'pixel_size': spec['pixel_size'] / scale, 'directions': {},
        'adoption': 'internally reviewed demo candidate; user art acceptance not claimed',
        'mirrors': {'W': 'E', 'SW': 'SE', 'NW': 'NE'},
        'mirror_note': 'Mirroring reverses handedness. World root and all muzzle pixels mirror together.',
        'sources': [],
    }
    for direction, definitions in spec['directions'].items():
        manifest['directions'][direction] = {'clips': {}}
        for name, definition in definitions.items():
            pack_file = ROOT / definition['pack']
            assert pack_file.resolve().is_relative_to(ROOT / 'Assets/Characters/Working')
            pack = json.loads(pack_file.read_text(encoding='utf-8'))
            quality = json.loads((pack_file.parent / 'quality.json').read_text(encoding='utf-8'))
            job = pack_file.parent.parent
            rejection = job / 'world-style-rejection-20261011.json'
            assert not rejection.is_file(), f'User rejected this world-art style: {job}'
            review = json.loads((job / 'visual-review.json').read_text(encoding='utf-8'))
            assert review.get('runtime_candidate') is True, f'No positive internal review: {job}'
            if review.get('approved_packs'):
                assert pack_file.parent.name in review['approved_packs'],f'Unreviewed derived pack: {pack_file}'
            if review.get('approved_pack_sha256'):
                assert review['approved_pack_sha256'][pack_file.parent.name]==digest(pack_file),'Reviewed pack changed'
            original_name = definition.get('clip', name)
            assert original_name not in review.get('rejected_clips',[]),f'Rejected clip {original_name}: {job}'
            if review.get('approved_clips'):assert original_name in review['approved_clips'],'Unreviewed clip'
            source_clip = copy.deepcopy(pack['clips'][original_name])
            if definition.get('hold_first_frame'):
                source_clip['rects'] = source_clip['rects'][:1]
                source_clip['frames'] = 1
                source_clip['duration'] = 1 / source_clip['fps']
                source_clip['review_note'] = 'Stable held first H3 frame; no dedicated breathing animation claimed.'
            assert quality['clips'][original_name]['edge_clip_pixels'] == 0
            assert quality['clips'][original_name]['green_fringe_pixels_above_threshold'] == 0
            assert pack['canvas'] == spec['canvas'] and pack['pivot_px'] == spec['pivot_px']
            source_image = pack_file.parent / source_clip['atlas']
            if review.get('approved_atlas_sha256'):
                assert review['approved_atlas_sha256'][original_name]==digest(source_image),'Reviewed atlas changed'
            target = output / f'{direction}-{name}.png'
            image = Image.open(source_image).convert('RGBA')
            encoded = io.BytesIO()
            image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS).save(encoded, format='PNG')
            pixels = encoded.getvalue()
            if not target.exists() or target.read_bytes() != pixels:
                target.write_bytes(pixels)
            clip = {k: v for k, v in source_clip.items() if k not in ['source', 'source_range', 'rects', 'atlas']}
            clip['atlas'] = 'res://' + target.relative_to(ROOT / 'Godot').as_posix()
            clip['rects'] = [{'frame': [round(x * scale) for x in r['frame']], 'source_frame': r['source_frame']} for r in source_clip['rects']]
            if 'release_source_frame' in definition:
                release = next(i for i, rect in enumerate(source_clip['rects']) if rect['source_frame'] >= definition['release_source_frame'])
                clip['release_time'] = release / clip['fps']
                clip['release_frame'] = release
            if 'muzzle_px' in definition:
                clip['muzzle_px'] = [x * scale for x in definition['muzzle_px']]
            if 'mouth_stability_recipe' in definition:
                assert scale == 1, 'Review mouth sampling again before changing runtime pixel scale.'
                detail_path = ROOT / definition['mouth_stability_recipe']
                detail = json.loads(detail_path.read_text(encoding='utf-8'))
                tracks = {item['source_frame']: item for item in detail['source_frames']}
                clip['mouth_stability'] = {
                    'reference_texture': detail['reference_texture'],
                    'reference_rect_uv': detail['reference_rect_uv'],
                    'target_rects_uv': [tracks[item['source_frame']]['rect_uv'] for item in source_clip['rects']],
                    'recipe': definition['mouth_stability_recipe'], 'recipe_sha256': digest(detail_path),
                }
            manifest['directions'][direction]['clips'][name] = clip
            manifest['sources'].append({'direction': direction, 'clip': name, 'pack': pack_file.relative_to(ROOT).as_posix(),
                                        'pack_sha256': digest(pack_file), 'runtime_atlas_sha256': digest(target),
                                        'prompt_id': json.loads((job / 'submission.json').read_text())['prompt_id']})
    (output / 'motion-set.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (output / 'publish-recipe.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(output), 'directions': list(manifest['directions']), 'clips': len(manifest['sources']), 'canvas': manifest['canvas']}))


if __name__ == '__main__':
    main()
