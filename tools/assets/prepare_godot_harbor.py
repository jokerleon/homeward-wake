"""Copy only the selected portable sprite atlases into the Godot visual project."""
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / 'Assets/Characters/Library/ShenYan/fullset-v01'
target = root / 'Godot/assets/characters'
target.mkdir(parents=True, exist_ok=True)
data = json.loads((source/'character-set.json').read_text(encoding='utf-8'))
runtime = {'directions': {}, 'source': source.relative_to(root).as_posix(), 'attack': 'not supplied'}
for direction, manifest in data['directions'].items():
    pack = json.loads((source/manifest).read_text(encoding='utf-8'))
    dest = target / direction
    dest.mkdir(exist_ok=True)
    for clip in pack['clips'].values():
        shutil.copy2(source/direction/clip['atlas'], dest/clip['atlas'])
        clip['atlas'] = f'res://assets/characters/{direction}/{clip["atlas"]}'
    runtime['directions'][direction] = pack
(target/'hero.json').write_text(json.dumps(runtime,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'directions':len(runtime['directions']),'atlases':sum(len(v['clips']) for v in runtime['directions'].values())}))
