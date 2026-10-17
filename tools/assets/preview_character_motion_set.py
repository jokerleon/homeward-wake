"""Playable review page plus GIF/MP4 previews made from the delivered PNG frames."""
import argparse
from functools import lru_cache
import json
import math
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont

ORDER=['S','SE','E','NE','N','NW','W','SW']
LABELS={'S':'正面 S','SE':'右前 SE','E':'右侧 E','NE':'右后 NE','N':'背面 N','NW':'左后 NW','W':'左侧 W','SW':'左前 SW'}


def sequence(pack,mode):
    clips=pack['clips']
    if mode=='idle':return [('idle',0,clips['idle']['frames'])]
    if mode in ('attack','hit'):
        return [('idle',0,10),(mode,0,clips[mode]['frames']),('idle',0,24)]
    exit_frame=pack['transitions']['move_loop_to_move_stop']['exit_before_frame']
    result=[('idle',0,12),('move_start',0,clips['move_start']['frames']),
            ('move_loop',0,clips['move_loop']['frames']),('move_loop',0,clips['move_loop']['frames'])]
    if exit_frame:result.append(('move_loop',0,exit_frame))
    return result+[('move_stop',0,clips['move_stop']['frames']),('idle',0,18)]


def at_time(pack,seq,t):
    for name,start,end in seq:
        fps=pack['clips'][name]['fps'];duration=(end-start)/fps
        if t<duration:return name,min(end-1,start+int(t*fps))
        t-=duration
    return 'idle',int(t*pack['clips']['idle']['fps'])%pack['clips']['idle']['frames']


HTML='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>沈砚 · 八方向动作检查</title>
<style>*{box-sizing:border-box}body{margin:0;background:#141d22;color:#e7edf0;font:15px/1.6 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1160px;margin:auto;padding:28px}h1{font-size:27px;font-weight:600;margin:0 0 5px}p{color:#aebdc6;margin:0 0 18px}nav{display:flex;gap:9px;align-items:center;flex-wrap:wrap;margin:22px 0}button,select{font:inherit;color:inherit;background:#26363f;border:1px solid #42545f;border-radius:5px;padding:7px 13px;cursor:pointer}button[aria-pressed=true]{background:#d7b574;color:#152026;border-color:#d7b574}label{display:flex;align-items:center;gap:8px;margin-left:8px}input[type=range]{flex:1;min-width:180px;accent-color:#d7b574}.scrub{display:flex;gap:12px;align-items:center;margin:0 0 20px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.tile{background:var(--bg,#273238);border-radius:4px;overflow:hidden}.caption{display:flex;justify-content:space-between;padding:8px 12px;color:#d6e1e5;font-size:13px}.caption small{color:#8ea4ae}canvas{display:block;width:100%;height:auto}.state{padding:0 12px 10px;font:12px ui-monospace,monospace;color:#96abb6}footer{margin-top:20px;color:#aebdc6;font-size:13px}a{color:#e0be7b}#status{color:#e0be7b} @media(max-width:760px){.grid{grid-template-columns:repeat(2,1fr)}main{padding:16px}}</style>
<main><h1>沈砚 · 八方向基础动作</h1><p>同一套透明图集。5 个实制方向 + 3 个镜像方向；新动作与步态细节待视觉确认。</p>
<nav id="modes"><button data-mode="idle">呼吸待机</button><button data-mode="movement">移动全程</button><button data-mode="attack">单刀攻击</button><button data-mode="hit">受击恢复</button><button id="play">暂停</button><button id="restart">重播</button><label>速度<select id="speed"><option value="0.5">0.5×</option><option selected value="1">1×</option><option value="1.5">1.5×</option></select></label><label>背景<select id="background"><option value="#273238">蓝灰</option><option value="#f0f0ed">浅色</option><option value="#080c10">深色</option></select></label><label><input type="checkbox" id="root">锚点</label></nav>
<div class="scrub"><button id="prev" title="按检查时间轴后退 1/60 秒">− 1/60s</button><input id="timeline" type="range" min="0" max="10" step="0.0166667" value="0"><button id="next" title="按检查时间轴前进 1/60 秒">+ 1/60s</button><span id="time">0.00s</span></div>
<p id="status">正在读取图集…</p><div class="grid" id="grid"></div><footer>移动按真实进入、循环与退出相位播放，先循环两次再收步。攻击内含模型生成的浅色刀痕，未分离成特效层。背向移动有轻微转腰、收步较长。此页是素材检查器，正式游戏控制器尚未接入。<br><a href="../character-set.json">动作数据</a></footer></main>
<script>const PACKS=__PACKS__, SEQUENCES=__SEQUENCES__, LABELS=__LABELS__, ORDER=__ORDER__;
let mode='movement',playing=true,time=0,last=performance.now(),generation=0;const images=new Map(),panels={};
for(const d of ORDER){const div=document.createElement('div');div.className='tile';div.innerHTML=`<div class="caption"><span>${LABELS[d]}</span><small>${PACKS[d].derived_from?'镜像':'实制'}</small></div><canvas width="288" height="288" aria-label="${LABELS[d]}动画"></canvas><div class="state"></div>`;document.querySelector('#grid').append(div);panels[d]={canvas:div.querySelector('canvas'),state:div.querySelector('.state')}}
function duration(d){return SEQUENCES[mode][d].reduce((n,[name,a,b])=>n+(b-a)/PACKS[d].clips[name].fps,0)}
function total(){return Math.max(...ORDER.map(duration))}
function sample(d,t){let p=PACKS[d];for(const [name,a,b] of SEQUENCES[mode][d]){let fps=p.clips[name].fps,dt=(b-a)/fps;if(t<dt)return [name,Math.min(b-1,a+Math.floor(t*fps))];t-=dt}return ['idle',Math.floor(t*p.clips.idle.fps)%p.clips.idle.frames]}
function load(d,name){let key=d+'/'+name;if(images.has(key))return images.get(key);let img=new Image();let promise=new Promise((resolve,reject)=>{img.onload=()=>resolve(img);img.onerror=()=>reject(new Error(key+' 图集无法读取'))});img.src='../'+d+'/'+PACKS[d].clips[name].atlas;let entry={img,promise};images.set(key,entry);return entry}
async function setMode(value){mode=value;time=0;let current=++generation;document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===mode)));document.querySelector('#timeline').max=total();document.querySelector('#status').textContent='正在读取图集…';try{let needed=[];for(const d of ORDER)for(const name of new Set(SEQUENCES[mode][d].map(s=>s[0])))needed.push(load(d,name).promise);await Promise.all(needed);if(current===generation)document.querySelector('#status').textContent='图集就绪 · 可暂停并拖动时间轴检查'}catch(e){document.querySelector('#status').textContent=e.message}}
function draw(){for(const d of ORDER){const [name,index]=sample(d,time),p=PACKS[d],c=p.clips[name],r=c.rects[index].frame,ctx=panels[d].canvas.getContext('2d');ctx.clearRect(0,0,288,288);let image=load(d,name).img;if(image.complete&&image.naturalWidth)ctx.drawImage(image,...r,0,0,288,288);if(document.querySelector('#root').checked){ctx.strokeStyle='#e0b772';ctx.beginPath();let [x,y]=p.pivot_px;ctx.moveTo(x-5,y);ctx.lineTo(x+5,y);ctx.moveTo(x,y-5);ctx.lineTo(x,y+5);ctx.stroke()}panels[d].state.textContent=`${name} · ${index+1}/${c.frames} · ${c.fps} fps`}document.querySelector('#timeline').value=time;document.querySelector('#time').textContent=time.toFixed(2)+'s'}
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>setMode(b.dataset.mode));document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#restart').onclick=()=>{time=0;draw()};document.querySelector('#timeline').oninput=e=>{time=+e.target.value;playing=false;document.querySelector('#play').textContent='播放';draw()};for(const [id,delta] of [['prev',-1/60],['next',1/60]])document.getElementById(id).onclick=()=>{playing=false;time=Math.max(0,Math.min(total(),time+delta));document.querySelector('#play').textContent='播放';draw()};document.querySelector('#background').onchange=e=>{document.documentElement.style.setProperty('--bg',e.target.value);const light=e.target.value==='#f0f0ed';document.querySelectorAll('.caption').forEach(el=>el.style.color=light?'#283943':'#d6e1e5');document.querySelectorAll('.state,.caption small').forEach(el=>el.style.color=light?'#51636d':'#96abb6')};
function frame(now){let dt=Math.max(0,Math.min(.1,(now-last)/1000));last=now;if(playing)time=(time+dt*+document.querySelector('#speed').value)%total();draw();requestAnimationFrame(frame)}setMode(mode);requestAnimationFrame(frame);
</script></html>'''


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--manifest',required=True);parser.add_argument('--page-only',action='store_true');args=parser.parse_args()
    source=Path(args.manifest).resolve();root=source.parent;out=root/'previews';out.mkdir(exist_ok=True)
    data=json.loads(source.read_text(encoding='utf-8'))
    packs={d:json.loads((root/data['directions'][d]).read_text(encoding='utf-8')) for d in ORDER}
    modes=['idle','movement']+[name for name in ['attack','hit'] if all(name in p['clips'] for p in packs.values())]
    sequences={mode:{d:sequence(packs[d],mode) for d in ORDER} for mode in modes}
    page=HTML.replace('__PACKS__',json.dumps(packs,ensure_ascii=False)).replace('__SEQUENCES__',json.dumps(sequences)).replace('__LABELS__',json.dumps(LABELS,ensure_ascii=False)).replace('__ORDER__',json.dumps(ORDER))
    if 'attack' not in modes:
        page=page.replace('<button data-mode="attack">单刀攻击</button>','')
        page=page.replace('攻击内含模型生成的浅色刀痕，未分离成特效层。','攻击尚无合格素材，已从正式目录清除。')
        page=page.replace('新动作与步态细节待视觉确认。','待机、移动与受击已获用户认可；当前未提供攻击。')
    if data.get('visual_review',{}).get('attack',{}).get('status')=='not_accepted':
        page=page.replace('新动作与步态细节待视觉确认。','用户已反馈攻击几乎都不合格：攻击组未通过，保留用于分析，不作为已接受的生产动作。')
    (out/'index.html').write_text(page,encoding='utf-8')
    if args.page_only:return
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',13)
    @lru_cache(maxsize=256)
    def sprite(d,name,index):return Image.open(root/d/packs[d]['clips'][name]['rects'][index]['file']).convert('RGBA').resize((202,202),Image.Resampling.LANCZOS)
    def render(mode,t):
        frame=Image.new('RGB',(832,464),(39,50,56));draw=ImageDraw.Draw(frame)
        for i,d in enumerate(ORDER):
            x=(i%4)*208;y=(i//4)*232
            name,index=at_time(packs[d],sequences[mode][d],t);image=sprite(d,name,index)
            frame.paste(image,(x+3,y+20),image)
            draw.text((x+8,y+2),LABELS[d]+(' · 镜像' if d in data['mirrored_directions'] else ''),font=font,fill=(226,233,236))
            draw.text((x+8,y+216),name+'  '+str(index),fill=(152,173,182))
        return frame
    for mode in sequences:
        duration=max(sum((b-a)/packs[d]['clips'][name]['fps'] for name,a,b in sequences[mode][d]) for d in ORDER)
        fps=24;frames=[render(mode,i/fps) for i in range(math.ceil(duration*fps))]
        ms=[round((i+1)*1000/fps)-round(i*1000/fps) for i in range(len(frames))]
        frames[0].save(out/(mode+'-eight.gif'),save_all=True,append_images=frames[1:],duration=ms,loop=0,disposal=2)
        del frames
        command=[shutil.which('ffmpeg'),'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','832x464','-r','60','-i','-','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(mode+'-eight.mp4'))]
        process=subprocess.Popen(command,stdin=subprocess.PIPE)
        for i in range(math.ceil(duration*60)):process.stdin.write(render(mode,i/60).tobytes())
        process.stdin.close();assert process.wait()==0
        print(mode,round(duration,3),'seconds',flush=True)


if __name__=='__main__':main()
