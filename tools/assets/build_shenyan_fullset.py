"""Author-reviewed cuts, standard packaging, deterministic mirrors and set manifest."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image

from analyze_shenyan_fullset import CANVAS, PIVOT, OUT, ROOT, sources
from package_character_motion import package

LIBRARY=ROOT/'Assets/Characters/Library/ShenYan/fullset-v01'
RECIPES=ROOT/'Assets/Characters/Recipes/shenyan-fullset-v01'
DIRECTIONS=['S','SW','W','NW','N','NE','E','SE']
MIRRORS={'SW':'SE','W':'E','NW':'NE'}
# start, loop end (exclusive), stop source start, loop exit-before phase
MOVES={'SE':(21,53,100,15),'S':(22,61,107,37),'E':(32,73,96,23),
       'NE':(24,55,107,25),'N':(40,77,77,0)}
# Kept inclusive source sections. Static holds are removed, motion is never reversed.
# Rejected attacks were removed from active use at the user's request. No default attack cuts:
# a new attack must pass review before a separate explicit recipe can adopt it.
HITS={'SE':([(44,65),(86,115),(123,123)],48,60),'S':([(5,20),(31,58),(123,123)],48,15),
      'E':([(5,20),(32,61),(123,123)],48,16),'NE':([(12,29),(42,73),(123,123)],48,24),
      'N':([(44,65),(88,115),(123,123)],48,60)}


def write(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def action_clip(name, settings):
    sections,fps,event_source=settings
    indices=[i for a,b in sections for i in range(a,b+1)]
    event_frame=indices.index(event_source)
    return dict(source=name,range=[indices[0],indices[-1]+1],source_frames=indices,fps=fps,loop=False,
        events=[dict(name='impact' if name=='attack' else 'reaction_peak',frame=event_frame,
                     source_frame=event_source,time_seconds=event_frame/fps)],
        interruptible=name=='hit',review_note='Authored source sections remove idle holds; playback FPS increases tempo without interpolating or redrawing frames. Final source frame restores the input idle pose.')


def recipes():
    source_sets=sources()
    for d in source_sets:
        start,end,stop,exit_frame=MOVES[d]
        spec=dict(version=1,character='ShenYan',direction=d,
            output=str((LIBRARY/d).relative_to(ROOT)),canvas=CANVAS,pivot=PIVOT,
            source_scale=.4,fps=24,sources=source_sets[d],
            clips={'idle':dict(source='idle',range=[0,124],loop=True),
                   'move_start':dict(source='move',range=[0,start],loop=False),
                   'move_loop':dict(source='move',range=[start,end],loop=True),
                   'move_stop':dict(source='move',range=[stop,124],loop=False),
                   'hit':action_clip('hit',HITS[d])},
            transitions={'idle_to_move_start':dict(mode='immediate',enter_frame=0,max_wait_frames=0),
                         'move_start_to_move_loop':dict(enter_frame=0),
                         'move_loop_to_move_stop':dict(exit_before_frame=exit_frame,max_wait_frames=end-start-1),
                         'move_stop_to_idle':dict(enter_frame=0),
                         'hit_to_idle':dict(enter_frame=0),
                         'hit_interrupt':dict(mode='immediate'),
                         'short_move':'Fit world movement to continuous start/loop/stop phases; never restart at each tile.'},
            root_track_note='Fixed ground point per source. Torso lean and foot bounce are not canceled.',
            adoption='User accepted idle, movement and hit on 2026-09-08; rejected attacks were removed from active use.',
            review_notes=['Attack is absent pending a newly reviewed single-direction result.',
                          'Hit is one brief recoil and recovery, with no injury layer.',
                          'Only idle, three movement phases and hit are supplied.'])
        if d=='N':spec['review_notes'].append('N movement varies its torso yaw during the source. The longer stop begins at the natural loop continuation to avoid a hard pose jump.')
        write(RECIPES/(d+'.json'),spec)
    print('Wrote five independent source-direction recipes.')


def mirror(target, source):
    origin=LIBRARY/source;dest=LIBRARY/target;dest.mkdir(parents=True,exist_ok=True)
    data=deepcopy(json.loads((origin/'motion.json').read_text(encoding='utf-8')))
    data['directions']=[target];data['missing_directions']=[d for d in DIRECTIONS if d!=target]
    data['possible_mirror']={};data['derived_from']=dict(direction=source,operation='horizontal_mirror',
        source_manifest_sha256=hashlib.sha256((origin/'motion.json').read_bytes()).hexdigest(),
        handedness='All clips flip together; mirrored character holds the weapon in the opposite anatomical hand, as authorized.')
    w,h=data['canvas'];data['pivot_px'][0]=w-data['pivot_px'][0]
    data['pivot_normalized'][0]=1-data['pivot_normalized'][0]
    for name,c in data['clips'].items():
        atlas=Image.new('RGBA',(w*c['columns'],h*c['rows']))
        for r in c['rects']:
            image=Image.open(origin/r['file']).convert('RGBA').transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            path=dest/r['file'];path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
            x,y,_,_=r['frame'];atlas.paste(image,(x,y))
        atlas.save(dest/c['atlas'])
    write(dest/'motion.json',data)
    write(dest/'quality.json',dict(status='Derived deterministic mirror; checked separately by set validator.',
        source_direction=source,generated_api_calls=0))


def finalize():
    for target,source in MIRRORS.items():mirror(target,source)
    manifest=dict(schema='character-motion-set/v1',character='ShenYan',version='fullset-v01',
        source_directions=['S','SE','E','NE','N'],mirrored_directions=MIRRORS,missing_directions=[],
        directions={d:f'{d}/motion.json' for d in DIRECTIONS},
        clips=['idle','move_start','move_loop','move_stop','hit'],missing_clips=['attack'],canvas=CANVAS,pivot_px=PIVOT,
        source_trial=str(OUT.relative_to(ROOT)),recipes=str(RECIPES.relative_to(ROOT)),
        adoption='User accepted idle, movement and hit on 2026-09-08. Rejected attacks removed; no accepted attack supplied.',
        runtime='Portable RGBA frames, atlases and events. No Godot import or gameplay validation yet.')
    set_file=LIBRARY/'character-set.json'
    if set_file.exists():
        prior=json.loads(set_file.read_text(encoding='utf-8'))
        if prior.get('visual_review'):manifest['visual_review']=prior['visual_review']
    write(set_file,manifest)
    if (LIBRARY/'generation-cost.json').exists():
        print('Assembled eight directions, five accepted clips each. Preserved original generation cost receipt.')
        return
    plan=json.loads((OUT/'plan.json').read_text(encoding='utf-8'));receipts=[]
    for job in plan['jobs']+plan.get('corrections',[]):
        result=json.loads((ROOT/job['folder']/'latest-status.json').read_text(encoding='utf-8'))
        assert result['task']['status']=='succeeded'
        tokens=result['tokenhub_usage']['total_tokens']
        receipts.append(dict(direction=job['direction'],action=job['action'],folder=job['folder'],
                             tokens=tokens,reference_cny=tokens*10/1_000_000,
                             replaced_by_correction=job['direction']=='SE' and 'corrections' not in job['folder']))
    write(LIBRARY/'generation-cost.json',dict(jobs=receipts,total_video_cny=sum(r['reference_cny'] for r in receipts),
        new_video_jobs=20,selected_new_video_jobs=18,reused_existing_video_jobs=2,
        imagegen_calls=6,imagegen_cny=None,
        note='Token usage at 10 CNY/million, not a reconciled billing-center statement. Two concurrency rejections created no tasks.',
        price_source='https://cloud.tencent.cn/document/product/1823/130055'))
    print('Assembled eight directions, five clips each; generated no new media.')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['recipes','package','finalize']);p.add_argument('--direction');args=p.parse_args()
    if args.action=='recipes':recipes()
    elif args.action=='finalize':finalize()
    else:
        for spec in sorted(RECIPES.glob('*.json')):
            if args.direction and spec.stem!=args.direction:continue
            package(spec,shutil.which('ffmpeg'))
