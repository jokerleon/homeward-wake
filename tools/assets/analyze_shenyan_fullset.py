"""Build source records and rank loop candidates; authoring review remains required."""
import json
from pathlib import Path
import shutil
import subprocess

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Assets/Characters/Trials/ShenYan/2026-09-08-h3-fullset'
CANVAS=[288,288]
PIVOT=[144,208]


def sources():
    plan=json.loads((OUT/'plan.json').read_text(encoding='utf-8'))
    result={d:{} for d in plan['source_directions']}
    for job in plan['jobs']+plan.get('corrections',[]):
        if job['action']=='attack' or job.get('asset_status')=='rejected_deleted':
            continue
        if job['direction']=='SE' and '/corrections/' not in job['folder'].replace('\\','/'):
            continue
        frame=job['framing'];size=frame.get('input_size',[1024,1024]);ground=frame['input_ground']
        root=[ground[i]*480/size[i] for i in range(2)]
        result[job['direction']][job['action']]=dict(file=job['folder']+'/source.mp4',
            root_track=[[0,*root],[123,*root]],source_scale=frame['output_to_match_v01_height'])
    prior=json.loads((ROOT/'Assets/Characters/Recipes/shenyan-combat-v01.json').read_text(encoding='utf-8'))
    result['SE']['idle']=dict(prior['sources']['idle'],source_scale=.4)
    result['SE']['move']=dict(prior['sources']['combat'],source_scale=.4)
    return result


def decode(source):
    scale=source['source_scale'];rx,ry=source['root_track'][0][1:]
    graph=(f'[1:v]setpts=PTS-STARTPTS,format=rgba,colorkey=0x00ff00:0.22:0.08,despill=type=green,'
           f'scale=iw*{scale}:ih*{scale}:flags=lanczos[fg];'
           f'[0:v][fg]overlay=x={PIVOT[0]-scale*rx}:y={PIVOT[1]-scale*ry}:format=auto:shortest=1,format=rgba[out]')
    command=[shutil.which('ffmpeg'),'-hide_banner','-loglevel','error','-f','lavfi','-i',
        'color=c=black@0:s=288x288:r=24,format=rgba','-i',str(ROOT/source['file']),
        '-filter_complex',graph,'-map','[out]','-an','-f','rawvideo','-pix_fmt','rgba','-']
    return np.frombuffer(subprocess.run(command,check=True,capture_output=True).stdout,np.uint8).reshape(-1,288,288,4)


def features(frames):
    f=np.stack([cv2.resize(x,(72,72),interpolation=cv2.INTER_AREA) for x in frames]).astype(np.float32)/255
    rgb=f[:,:,:,:3]*f[:,:,:,3:4]
    weight=np.ones((72,72,1),np.float32);weight[39:59]=2.5
    return np.concatenate([rgb,f[:,:,:,3:4]],axis=3)*weight


def loops(frames):
    f=features(frames);velocity=np.diff(f,axis=0)
    scored=[]
    for start in range(16,43):
        for period in range(20,43):
            end=start+period
            pose=float(np.abs(f[start]-f[end]).mean())
            speed=float(np.abs(velocity[start]-velocity[end-1]).mean())
            internal=float(np.abs(velocity[start:end]).mean())
            score=pose+.35*speed+.00002*(start-16)
            scored.append(dict(start=start,end=end,period=period,pose_error=pose,velocity_error=speed,
                average_step=internal,score=score))
    # Keep structurally distinct candidates, rather than five adjacent frame pairs.
    ranked=[]
    for c in sorted(scored,key=lambda c:c['score']):
        if any(abs(c['start']-r['start'])<3 and abs(c['period']-r['period'])<3 for r in ranked):continue
        start,end=c['start'],c['end'];best=None
        for stop in range(96,110):
            for k in range(start,end):
                pose=float(np.abs(f[k]-f[stop]).mean())
                vel=float(np.abs(velocity[k-1]-velocity[stop-1]).mean())
                score=pose+.2*vel
                if best is None or score<best['score']:
                    best=dict(stop_source_frame=stop,exit_before_frame=k-start,pose_error=pose,score=score)
        c['stop_join']=best;ranked.append(c)
        if len(ranked)==6:break
    return ranked


def main():
    records=sources();review=OUT/'analysis';review.mkdir(exist_ok=True)
    all_reports={};pose_sheet=Image.new('RGB',(288*5,288*3),(39,50,56))
    for column,(direction,source_set) in enumerate(records.items()):
        for row,action in enumerate(['idle','move','hit']):
            frames=decode(source_set[action]);assert len(frames)==124
            bg=Image.new('RGBA',(288,288),(39,50,56,255));bg.alpha_composite(Image.fromarray(frames[0]))
            ImageDraw.Draw(bg).text((8,8),direction+'/'+action,fill='white');pose_sheet.paste(bg.convert('RGB'),(column*288,row*288))
            if action!='move':continue
            candidates=loops(frames) if direction!='SE' else []
            all_reports[direction]=dict(sources=source_set,loop_candidates=candidates)
            if candidates:
                contact=Image.new('RGB',(288*6,288*len(candidates)),(39,50,56))
                for j,c in enumerate(candidates):
                    a,b=c['start'],c['end'];stop=c['stop_join']['stop_source_frame']
                    for k,index in enumerate([a-1,a,a+1,b-1,b,stop]):
                        bg=Image.new('RGBA',(288,288),(39,50,56,255));bg.alpha_composite(Image.fromarray(frames[index]))
                        ImageDraw.Draw(bg).text((8,8),f'#{j} {direction} source {index}',fill='white')
                        contact.paste(bg.convert('RGB'),(k*288,j*288))
                contact.save(review/f'{direction}-loop-candidates.png')
            print(direction,json.dumps(candidates[:2]),flush=True)
    pose_sheet.save(review/'initial-pose-registration.png')
    (review/'sources-and-candidates.json').write_text(json.dumps(all_reports,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
