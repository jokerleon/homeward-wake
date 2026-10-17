"""Separate an imagegen turnaround board into single-view H3 source canvases.

No generative repaint or animation-frame alignment. Original board is retained.
"""
from pathlib import Path
import argparse,hashlib,json
import cv2
import numpy as np
from PIL import Image

def extract(source,output,directions):
    image=Image.open(source).convert('RGBA');pixels=np.array(image)
    count,labels,stats,centers=cv2.connectedComponentsWithStats((pixels[:,:,3]>32).astype('uint8'))
    large=sorted(range(1,count),key=lambda i:int(stats[i,cv2.CC_STAT_AREA]),reverse=True)[:len(directions)]
    assert len(large)==len(directions) and min(stats[i,cv2.CC_STAT_AREA] for i in large)>5000,'Separate full figures not proven.'
    large.sort(key=lambda i:float(centers[i,0]))
    distances=np.stack([cv2.distanceTransform((labels!=i).astype('uint8'),cv2.DIST_L2,3) for i in large])
    ownership=np.argmin(distances,axis=0)
    output.mkdir(parents=True,exist_ok=True)
    records=[]
    for index,(component,direction) in enumerate(zip(large,directions)):
        isolated=pixels.copy();isolated[ownership!=index]=0
        alpha=isolated[:,:,3];ys,xs=np.where(alpha>32)
        box=[int(xs.min()),0,int(xs.max())+1,image.height]
        cropped=Image.fromarray(isolated,'RGBA').crop(box)
        side=max(image.height,cropped.width+64)
        canvas=Image.new('RGBA',(side,side));canvas.alpha_composite(cropped,((side-cropped.width)//2,(side-image.height)//2))
        path=output/(direction+'.png');canvas.save(path)
        assert not np.any(np.array(canvas.getchannel('A'))[[0,-1],:]>16),'Figure touches source edge.'
        edge_pixels=int(np.count_nonzero(alpha[0,:]>32)+np.count_nonzero(alpha[-1,:]>32)+np.count_nonzero(alpha[:,0]>32)+np.count_nonzero(alpha[:,-1]>32))
        records.append({'direction':direction,'file':path.name,'source_component':int(component),'source_x_crop':box,'canvas':canvas.size,'source_edge_pixels':edge_pixels,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    record={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_size':image.size,'method':'Five largest separated alpha silhouettes, ordered left to right. Low-alpha edge pixels assigned to nearest silhouette; no repaint. Full original vertical framing retained on square canvases; no per-frame registration.','directions':records}
    (output/'extraction.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--directions',nargs='+',default=['S','SE','E','NE','N'])
    args=parser.parse_args();extract(args.source,args.output,args.directions)
