"""Deterministic chroma-key processing for explicitly local H3 game assets."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

def key_rgba(im):
    im=im.convert('RGB')
    rgb=np.asarray(im).astype(np.float32)
    r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    excess=g-np.maximum(r,b)
    # Key the deliberately uniform green production backdrop; protect dark
    # blues, warm cloth and skin. Fractional edge alpha retains drawn outlines.
    background=np.clip((excess-22.0)/65.0,0,1)*np.clip((g-45.0)/65.0,0,1)
    alpha=1.0-background
    spill=np.maximum(0.0,excess-6.0)*(1.0-np.clip(alpha,0,1))
    rgb[:,:,1]=np.clip(g-spill,0,255)
    rgb[:,:,1]=np.where(alpha<.995,np.minimum(rgb[:,:,1],np.maximum(r,b)+5.0),rgb[:,:,1])
    # Thin painted outlines can carry fully opaque green spill even after the
    # backdrop is keyed. These blue/ivory/rust character palettes contain no
    # saturated green material; neutralize that excess without moving edges.
    rgb[:,:,1]=np.where(excess>18.0,np.minimum(rgb[:,:,1],np.maximum(r,b)+8.0),rgb[:,:,1])
    rgba=np.dstack([rgb,np.round(alpha*255)]).astype(np.uint8)
    rgba[rgba[:,:,3]==0,:3]=0
    output=Image.fromarray(rgba,'RGBA')
    return output

def key(source, target):
    im=Image.open(source).convert('RGB')
    output=key_rgba(im)
    rgba=np.asarray(output)
    target.parent.mkdir(parents=True,exist_ok=True)
    output.save(target)
    bounds=output.getchannel('A').getbbox()
    visible=rgba[:,:,3]>16
    residue=int(np.count_nonzero(visible&(rgba[:,:,1].astype(int)-np.maximum(rgba[:,:,0],rgba[:,:,2]).astype(int)>45)))
    sheet=Image.new('RGB',(im.width*2,im.height),(242,239,229))
    for i,color in enumerate([(242,239,229),(23,37,42)]):
        bg=Image.new('RGBA',im.size,color+(255,));bg.alpha_composite(output)
        sheet.paste(bg.convert('RGB'),(i*im.width,0))
    sheet.save(target.with_name(target.stem+'-alpha-review.png'))
    data={'source':str(source.resolve()),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output':str(target.resolve()),'output_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'size':im.size,'alpha_bbox':bounds,'remaining_green_pixels_above_threshold':residue,'method':'Deterministic chroma key and fractional-edge despill only; no generative repaint, pose correction or per-frame bounding-box alignment.','review':'Visual review required; metrics are not art acceptance.'}
    target.with_suffix('.processing.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(data,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('source',type=Path)
    parser.add_argument('target',type=Path)
    args=parser.parse_args()
    key(args.source,args.target)
