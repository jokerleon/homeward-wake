"""Bundle reviewed runtime frames, atlases, metadata, previews and recipes."""
import argparse
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',required=True);args=p.parse_args()
    source=Path(args.manifest).resolve();folder=source.parent
    assert folder.is_relative_to(ROOT/'Assets/Characters/Library')
    data=json.loads(source.read_text(encoding='utf-8'))
    validation=json.loads((folder/'validation.json').read_text(encoding='utf-8'))
    assert validation.get('validation_scope')=='portable_sprite_data_only','Run the current offline sprite-set validator before packaging.'
    assert set(validation['directions'])==set(data['directions'])
    archive=folder.parent/(data['character']+'-'+data['version']+'.zip')
    temporary=archive.with_suffix('.zip.tmp')
    files=[]
    with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for file in sorted(folder.rglob('*')):
            relative=file.relative_to(folder)
            if not file.is_file() or 'registered' in relative.parts:continue
            z.write(file,relative);files.append(relative.as_posix())
        recipes=ROOT/data['recipes']
        for file in sorted(recipes.glob('*.json')):z.write(file,'recipes/'+file.name)
    with zipfile.ZipFile(temporary) as z:
        assert z.testzip() is None
        frame_count=sum('/frames/' in '/'+n and n.endswith('.png') for n in z.namelist())
        assert frame_count==validation['frames']
    temporary.replace(archive)
    print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'frames':frame_count,'runtime_files':len(files)}))


if __name__=='__main__':main()
