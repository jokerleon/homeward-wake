"""Deterministic video-to-RGBA sprite packaging. No generation API or game edits."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]

def save(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def hashfile(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def expression(track, axis, fps):
    # FFmpeg overlay's n starts at 1, whereas recipe source frame indices start
    # at 0. Timestamp * FPS is zero-based for these explicitly reset streams.
    frame=f'(t*{fps})'
    result = str(track[-1][axis])
    for a,b in reversed(list(zip(track,track[1:]))):
        interp=f'({a[axis]}+({b[axis]}-{a[axis]})*({frame}-{a[0]})/{b[0]-a[0]})'
        result=f'if(lt({frame},{b[0]}),{interp},{result})'
    return result

def package(spec_path, ffmpeg):
    spec=json.loads(spec_path.read_text(encoding='utf-8-sig'))
    out=(ROOT/spec['output']).resolve()
    assert out.is_relative_to(ROOT/'Assets/Characters/Library') or (
        spec.get('stage')=='candidate' and out.is_relative_to(ROOT/'Assets/Characters/Working'))
    out.mkdir(parents=True,exist_ok=True)
    w,h=spec['canvas'];px,py=spec['pivot'];fps=spec['fps'];scale=spec['source_scale']
    assert 0<px<w and 0<py<h and fps>0
    source_files={}
    provenance={}
    for name,source in spec['sources'].items():
        video=ROOT/source['file'];assert video.is_file()
        source_scale=source.get('source_scale',scale)
        folder=out/'registered'/name;folder.mkdir(parents=True,exist_ok=True)
        x=f'{px}-{source_scale}*({expression(source["root_track"],1,fps)})'
        y=f'{py}-{source_scale}*({expression(source["root_track"],2,fps)})'
        graph=(f'[1:v]setpts=PTS-STARTPTS,format=rgba,colorkey=0x00ff00:0.22:0.08,despill=type=green,'
               f'scale=iw*{source_scale}:ih*{source_scale}:flags=lanczos[fg];'
               f"[0:v][fg]overlay=x='{x}':y='{y}':eval=frame:format=auto:shortest=1,format=rgba[out]")
        cmd=[ffmpeg,'-hide_banner','-loglevel','error','-y','-f','lavfi','-i',
             f'color=c=black@0:s={w}x{h}:r={fps},format=rgba','-i',str(video),
             '-filter_complex',graph,'-map','[out]','-an','-start_number','0',str(folder/'frame-%04d.png')]
        if spec.get('key_method')=='local_h3_green':
            from key_local_h3_image import key_rgba
            used_frames=set()
            for clip in spec['clips'].values():
                if clip['source']==name:used_frames.update(clip.get('source_frames',range(*clip['range'])))
            decoded=(ROOT/source['frames_dir']).resolve() if source.get('frames_dir') else out/'decoded-source'/name
            if not source.get('frames_dir'):
                decoded.mkdir(parents=True,exist_ok=True)
                subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(video),'-an','-start_number','0',str(decoded/'frame-%04d.png')],check=True)
            track=source['root_track']
            for frame_index,raw in enumerate(sorted(decoded.glob('*.png'))):
                left,right=track[0],track[-1]
                for a,b in zip(track,track[1:]):
                    if a[0]<=frame_index<=b[0]:left,right=a,b;break
                fraction=max(0.0,min(1.0,(frame_index-left[0])/max(1,right[0]-left[0])))
                rx=left[1]+(right[1]-left[1])*fraction
                ry=left[2]+(right[2]-left[2])*fraction
                keyed=key_rgba(Image.open(raw))
                isolation_rect=source.get('isolation_rect')
                for isolation in source.get('isolation_rects',[]):
                    if isolation['source_range'][0]<=frame_index<isolation['source_range'][1]:
                        isolation_rect=isolation['rect'];break
                if isolation_rect:
                    # An explicitly reviewed empty gutter can separate a generated
                    # projectile from the actor without deleting reaction frames.
                    # Never crop through character pixels at the authored boundary.
                    left,top,right,bottom=isolation_rect
                    alpha=np.array(keyed.getchannel('A'))
                    for x in [left,right]:
                        if 0<x<keyed.width:
                            assert not np.any(alpha[:,max(0,x-2):min(keyed.width,x+2)]>32),('Isolation crosses foreground',frame_index,x)
                    for y in [top,bottom]:
                        if 0<y<keyed.height:
                            assert not np.any(alpha[max(0,y-2):min(keyed.height,y+2),:]>32),('Isolation crosses foreground',frame_index,y)
                    isolated=Image.new('RGBA',keyed.size)
                    isolated.paste(keyed.crop((left,top,right,bottom)),(left,top))
                    keyed=isolated
                for exclusion in source.get('exclude_rects',[]):
                    if not exclusion['source_range'][0]<=frame_index<exclusion['source_range'][1]:continue
                    left,top,right,bottom=exclusion['rect']
                    assert 0<=left<right<=keyed.width and 0<=top<bottom<=keyed.height
                    alpha=np.array(keyed.getchannel('A'))
                    # Only remove a disconnected effect bounded by empty green
                    # gutters. Do not cut through a limb, bow, hand or projectile
                    # still attached to the weapon; such frames are excluded.
                    for x in [left,right]:
                        if 0<x<keyed.width:assert not np.any(alpha[top:bottom,max(0,x-2):min(keyed.width,x+2)]>32),('Exclusion crosses foreground',frame_index,x)
                    for y in [top,bottom]:
                        if 0<y<keyed.height:assert not np.any(alpha[max(0,y-2):min(keyed.height,y+2),left:right]>32),('Exclusion crosses foreground',frame_index,y)
                    keyed.paste((0,0,0,0),(left,top,right,bottom))
                if spec.get('require_source_margin') and frame_index in used_frames:
                    opaque=np.array(keyed.getchannel('A'))>64
                    source_edge=int(np.count_nonzero(opaque[:3])+np.count_nonzero(opaque[-3:])+np.count_nonzero(opaque[:,:3])+np.count_nonzero(opaque[:,-3:]))
                    assert source_edge==0,('Foreground reaches original video edge',name,frame_index,source_edge)
                registered=keyed.transform((w,h),Image.Transform.AFFINE,(1/source_scale,0,rx-px/source_scale,0,1/source_scale,ry-py/source_scale),Image.Resampling.BICUBIC)
                rgba=np.array(registered)
                rb=np.maximum(rgba[:,:,0],rgba[:,:,2]).astype(np.int16)
                spill=(rgba[:,:,1].astype(np.int16)>rb+18)&(rgba[:,:,3]>0)
                rgba[:,:,1]=np.where(spill,np.minimum(rb+8,255),rgba[:,:,1]).astype(np.uint8)
                registered=Image.fromarray(rgba,'RGBA')
                registered.save(folder/f'frame-{frame_index:04d}.png')
        else:
            subprocess.run(cmd,check=True)
        source_files[name]=sorted(folder.glob('frame-*.png'))
        provenance[name]={'file':source['file'],'sha256':hashfile(video),
                          'decoded_frames':len(source_files[name]),'root_track':source['root_track'],
                          'source_scale':source_scale}
        if source.get('frames_dir'):
            provenance[name]['lossless_frames_dir']=source['frames_dir']
            provenance[name]['lossless_frame_hashes']=[hashfile(p) for p in sorted(decoded.glob('*.png'))]
        if source.get('isolation_rect'):
            provenance[name]['isolation_rect']=source['isolation_rect']
            provenance[name]['isolation_note']=source.get('isolation_note','Explicit reviewed actor-only region; original frames retained.')
        if source.get('isolation_rects'):
            provenance[name]['isolation_rects']=source['isolation_rects']
            provenance[name]['isolation_note']=source.get('isolation_note','Explicit reviewed actor-only regions; original frames retained.')
        if source.get('exclude_rects'):
            provenance[name]['exclude_rects']=source['exclude_rects']
            provenance[name]['exclusion_note']=source.get('exclusion_note','Disconnected generated effect excluded across proven empty borders; original frames retained.')
    all_directions=['S','SW','W','NW','N','NE','E','SE']
    mirror_partner={'SE':'SW','E':'W','NE':'NW'}
    manifest={'schema':'character-motion-pack/v1','character':spec['character'],
              'directions':[spec['direction']],
              'possible_mirror':{mirror_partner[spec['direction']]:spec['direction']} if spec['direction'] in mirror_partner else {},
              'missing_directions':[d for d in all_directions if d!=spec['direction']],
              'canvas':spec['canvas'],'pivot_px':spec['pivot'],
              'pivot_normalized':[px/w,py/h],'alpha':'straight','color_space':'sRGB',
              'fps':fps,'clips':{},'transitions':spec['transitions'],
              'root_motion':'none; gameplay positions the root',
              'adoption':spec.get('adoption','candidate; visual review required'),'sources':provenance}
    if spec.get('review_notes'):manifest['review_notes']=spec['review_notes']
    if spec.get('alignment_checks'):manifest['alignment_checks']=spec['alignment_checks']
    stats={};previews=out/'previews';previews.mkdir(exist_ok=True)
    for name,clip in spec['clips'].items():
        begin,end=clip['range'];files=source_files[clip['source']]
        clip_fps=clip.get('fps',fps)
        assert 0<=begin<end<=len(files)
        indices=clip.get('source_frames',list(range(begin,end)))
        assert indices and all(begin<=i<end for i in indices) and indices==sorted(set(indices))
        chosen=[files[i] for i in indices];folder=out/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
        for old in folder.glob('*.png'):
            if old.stem.isdigit() and int(old.stem)>=len(chosen):old.unlink()
        cols=min(8,len(chosen));rows=math.ceil(len(chosen)/cols)
        atlas=Image.new('RGBA',(cols*w,rows*h));bounds=[];fringe=0;edge=0;entries=[]
        for i,p in enumerate(chosen):
            im=Image.open(p).convert('RGBA');assert im.size==(w,h)
            a=np.asarray(im);opaque=a[:,:,3]>16
            ys,xs=np.where(opaque);assert len(xs)>0
            bounds.append([int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())])
            edge+=int(np.count_nonzero(opaque[:3])+np.count_nonzero(opaque[-3:])+np.count_nonzero(opaque[:,:3])+np.count_nonzero(opaque[:,-3:]))
            rgb=a[:,:,:3].astype(int)
            fringe+=int(np.count_nonzero(opaque&(rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])>35)))
            target=folder/f'{i:04d}.png';shutil.copyfile(p,target)
            x=(i%cols)*w;y=(i//cols)*h;atlas.paste(im,(x,y))
            entries.append({'frame':[x,y,w,h],'source_frame':indices[i],'file':str(target.relative_to(out)).replace('\\','/')})
        assert edge==0,(name,'clipping at canvas edge',edge)
        atlas_path=out/(name+'.png');atlas.save(atlas_path)
        manifest['clips'][name]={'atlas':atlas_path.name,'columns':cols,'rows':rows,'frames':len(chosen),
                                'fps':clip_fps,'loop':clip['loop'],'duration':len(chosen)/clip_fps,
                                'source':clip['source'],'source_range':[begin,end],'rects':entries}
        for field in ['events','interruptible','review_note']:
            if field in clip:manifest['clips'][name][field]=clip[field]
        stats[name]={'frames':len(chosen),'all_rgba':True,'edge_clip_pixels':edge,
                     'source_margin_checked':bool(spec.get('require_source_margin') and spec.get('key_method')=='local_h3_green'),
                     'green_fringe_pixels_above_threshold':fringe,
                     'union_bbox':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]}
        # Unmodified motion with a preview-only background and root marker.
        frames=[]
        for p in chosen:
            bg=Image.new('RGBA',(w,h),(39,50,56,255));im=Image.open(p).convert('RGBA');bg.alpha_composite(im)
            d=ImageDraw.Draw(bg);d.line((px-5,py,px+5,py),fill=(218,185,94,255));d.line((px,py-4,px,py+4),fill=(218,185,94,255))
            frames.append(bg.convert('RGB'))
        duration=[round((i+1)*1000/clip_fps)-round(i*1000/clip_fps) for i in range(len(frames))]
        frames[0].save(previews/(name+'.gif'),save_all=True,append_images=frames[1:],duration=duration,loop=0,disposal=2)
    # Black/white checks reveal alpha errors that a grey preview conceals.
    names=list(manifest['clips'])
    sheet=Image.new('RGB',(w*len(names)*2,h*2),(225,225,225))
    for row,bgcolor in enumerate([(255,255,255),(12,16,20)]):
        for j,name in enumerate(names):
            clip=manifest['clips'][name]
            for k,idx in enumerate([0,clip['frames']//2]):
                im=Image.open(out/clip['rects'][idx]['file']).convert('RGBA')
                bg=Image.new('RGBA',(w,h),bgcolor+(255,));bg.alpha_composite(im)
                d=ImageDraw.Draw(bg);d.line((0,py,w,py),fill=(128,128,128,255));d.line((px-5,py,px+5,py),fill=(255,50,50,255))
                sheet.paste(bg.convert('RGB'),((j*2+k)*w,row*h))
    sheet.save(previews/'alpha-and-pivot.png')
    # Demonstrate the actual exit cue, rather than pretending that a stop clip
    # can be entered from every possible gait frame.
    def clipframes(name):
        return [Image.open(out/r['file']).convert('RGBA') for r in manifest['clips'][name]['rects']]
    if all(name in manifest['clips'] for name in ['idle','move_start','move_loop','move_stop']):
        idle=clipframes('idle');start=clipframes('move_start');loop=clipframes('move_loop');stop=clipframes('move_stop')
        exit_frame=manifest['transitions']['move_loop_to_move_stop']['exit_before_frame']
        sequence=idle[-12:]+start+loop*2+loop[:exit_frame]+stop+idle[:12]
    else:
        sequence=[]
    review=[]
    for im in sequence:
        bg=Image.new('RGBA',(w*2,h),(39,50,56,255))
        bg.alpha_composite(im,(0,0));bg.alpha_composite(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(w,0))
        draw=ImageDraw.Draw(bg)
        for x in (px,w+(w-px)):
            draw.line((x-5,py,x+5,py),fill=(218,185,94,255));draw.line((x,py-4,x,py+4),fill=(218,185,94,255))
        review.append(bg.convert('RGB'))
    ms=[round((i+1)*1000/fps)-round(i*1000/fps) for i in range(len(review))]
    if review:
        review[0].save(previews/'sequence-and-mirror.gif',save_all=True,append_images=review[1:],duration=ms,loop=0,disposal=2)
        preview_frames=previews/'sequence-and-mirror-frames'
        preview_frames.mkdir(exist_ok=True)
        for index,frame in enumerate(review):frame.save(preview_frames/f'{index:04d}.png')
        save(previews/'sequence-timing.json',{'frames':len(review),'fps':fps,'duration_seconds':len(review)/fps,'note':'Use lossless PNG sequence for exact-rate video. GIF timing is quantized to hundredths of a second.'})
    save(out/'motion.json',manifest)
    save(out/'quality.json',{'status':'technical-checks-passed; visual seams require review','clips':stats,
         'recipe_sha256':hashfile(spec_path),'source_scale':scale,'pivot_px':spec['pivot'],
         'root_track_note':spec['root_track_note'],'generated_api_calls':0})
    print(json.dumps({'output':str(out),'clips':{k:v['frames'] for k,v in manifest['clips'].items()},'quality':stats},ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--spec',required=True)
    p.add_argument('--ffmpeg',default=shutil.which('ffmpeg'));a=p.parse_args()
    assert a.ffmpeg,'ffmpeg is required'
    package(Path(a.spec).resolve(),a.ffmpeg)
