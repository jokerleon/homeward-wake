"""Validate portable sprite pixels and metadata, without engine-specific reports."""
import argparse
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image

p=argparse.ArgumentParser();p.add_argument('--manifest',required=True);a=p.parse_args()
file=Path(a.manifest).resolve();root=file.parent;m=json.loads(file.read_text(encoding='utf-8-sig'))
assert m['schema']=='character-motion-pack/v1'
assert set(m['directions']).isdisjoint(m['missing_directions'])
w,h=m['canvas'];px,py=m['pivot_px'];assert 0<px<w and 0<py<h
frames=0
for name,c in m['clips'].items():
    atlas=Image.open(root/c['atlas']);assert atlas.mode=='RGBA'
    assert len(c['rects'])==c['frames'] and abs(c['duration']-c['frames']/c['fps'])<1e-7
    assert atlas.size==(w*c['columns'],h*c['rows'])
    for r in c['rects']:
        im=Image.open(root/r['file']);assert im.mode=='RGBA' and im.size==(w,h)
        x,y,fw,fh=r['frame'];assert (fw,fh)==(w,h)
        assert np.array_equal(np.asarray(atlas.crop((x,y,x+w,y+h))),np.asarray(im))
        pixels=np.asarray(im);alpha=pixels[:,:,3]
        assert alpha.max()==255 and alpha.min()==0
        assert not alpha[0,:].any() and not alpha[-1,:].any() and not alpha[:,0].any() and not alpha[:,-1].any()
        frames+=1
if 'move_loop' in m['clips']:
    assert 0<=m['transitions']['move_loop_to_move_stop']['exit_before_frame']<m['clips']['move_loop']['frames']
result={'frames_checked':frames,'exact_atlas_frame_match':True,'transparent_border':True,
        'valid_transition_phase':True if 'move_loop' in m['clips'] else None}
if m.get('alignment_checks'):
    import cv2
    checks=m['alignment_checks'];details=[]
    def gray_at(pair):
        clip,frame=pair
        rgba=np.asarray(Image.open(root/m['clips'][clip]['rects'][frame]['file']).convert('RGBA'))
        return (cv2.cvtColor(rgba[:,:,:3],cv2.COLOR_RGB2GRAY).astype(np.float32)*rgba[:,:,3]/255).astype(np.float32)
    for pair in checks['pairs']:
        shift,response=cv2.phaseCorrelate(gray_at(pair['from']),gray_at(pair['to']))
        distance=math.hypot(*shift)
        assert response>=checks['min_correlation'],(pair['name'],'inconclusive alignment; inspect visually',response)
        assert distance<=checks['max_translation_px'],(pair['name'],'visible cut translation',shift)
        details.append({'cut':pair['name'],'shift_px':list(shift),'magnitude_px':distance,'correlation':response})
    result['alignment_checks']=details
result['validation_scope']='portable_sprite_data_only'
(root/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
