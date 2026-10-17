"""Validate coverage, pixels, mirrored handedness, events, and report actual seams."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image


def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',required=True);args=p.parse_args()
    source=Path(args.manifest).resolve();root=source.parent
    data=json.loads(source.read_text(encoding='utf-8'));assert data['schema']=='character-motion-set/v1'
    assert set(data['directions'])==set(['S','SW','W','NW','N','NE','E','SE']) and not data['missing_directions']
    packs={};report=dict(directions={},mirrors={},seams={},frames=0,events=0)
    for direction,relative in data['directions'].items():
        file=root/relative;m=json.loads(file.read_text(encoding='utf-8'));packs[direction]=m
        assert m['directions']==[direction] and set(m['clips'])==set(data['clips'])
        assert m['canvas']==data['canvas'] and m['pivot_px']==data['pivot_px']
        result=subprocess.run([sys.executable,str(Path(__file__).with_name('validate_character_motion_pack.py')),'--manifest',str(file)],capture_output=True,text=True,check=True)
        check=json.loads(result.stdout);report['directions'][direction]=check;report['frames']+=check['frames_checked']
        for name,c in m['clips'].items():
            for event in c.get('events',[]):
                assert 0<=event['frame']<c['frames']
                assert c['rects'][event['frame']]['source_frame']==event['source_frame']
                assert abs(event['time_seconds']-event['frame']/c['fps'])<1e-7
                report['events']+=1
        def rgba(name,index):return np.asarray(Image.open(file.parent/m['clips'][name]['rects'][index]['file']).convert('RGBA'))
        def gray(name,index):
            a=rgba(name,index)
            return (cv2.cvtColor(a[:,:,:3],cv2.COLOR_RGB2GRAY).astype(np.float32)*a[:,:,3]/255).astype(np.float32)
        def measure(label,a,b):
            shift,response=cv2.phaseCorrelate(gray(*a),gray(*b))
            return dict(cut=label,translation_estimate_px=list(shift),magnitude_px=math.hypot(*shift),correlation=response,
                        note='Whole-image estimate includes pose change; this alone is not a ground-slip or seamless-gait proof.')
        exit_frame=m['transitions']['move_loop_to_move_stop']['exit_before_frame']
        pairs=[('idle/start',('idle',0),('move_start',0)),('start/loop',('move_start',-1),('move_loop',0)),
               ('loop/repeat',('move_loop',-1),('move_loop',0)),('loop/stop',('move_loop',exit_frame-1),('move_stop',0)),
               ('stop/idle',('move_stop',-1),('idle',0)),('idle/attack',('idle',0),('attack',0)),
               ('attack/idle',('attack',-1),('idle',0)),('idle/hit',('idle',0),('hit',0)),('hit/idle',('hit',-1),('idle',0))]
        pairs=[q for q in pairs if q[1][0] in m['clips'] and q[2][0] in m['clips']]
        cuts=[measure(*q) for q in pairs]
        for name in ['attack','hit']:
            if name not in m['clips']:continue
            c=m['clips'][name]
            for i in range(1,c['frames']):
                if c['rects'][i]['source_frame']-c['rects'][i-1]['source_frame']>1:
                    cuts.append(measure(name+f'/hold-cut-{i}',(name,i-1),(name,i)))
        report['seams'][direction]=cuts
    for target,origin in data['mirrored_directions'].items():
        a,b=packs[target],packs[origin];checked=0
        for name,c in a['clips'].items():
            if 'events' in c:assert c['events']==b['clips'][name]['events']
            for i,r in enumerate(c['rects']):
                actual=np.asarray(Image.open(root/target/r['file']).convert('RGBA'))
                expected=np.asarray(Image.open(root/origin/b['clips'][name]['rects'][i]['file']).convert('RGBA'))[:,::-1,:]
                assert np.array_equal(actual,expected),(target,name,i,'mirror differs')
                checked+=1
        report['mirrors'][target]=dict(source=origin,frames_checked=checked,exact_horizontal_flip=True)
    report['validation_scope']='portable_sprite_data_only'
    report['status']='pixel, coverage, mirror and event checks passed; visual quality is a separate review'
    (root/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(frames=report['frames'],directions=len(packs),clips=sum(len(m['clips']) for m in packs.values()),
                         events=report['events'],mirrors=report['mirrors'],validation_scope=report['validation_scope'])))


if __name__=='__main__':main()
