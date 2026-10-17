"""Assemble unretouched evaluation outputs and a labeled H3 reference viewer."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / 'Assets/Characters/Working/Atang/qwen21-eval-v01'
LABELS = [('01-portrait-v02', '半身立绘'), ('02-explore', '空手探索'), ('03-combat-ready-v03', '持弩战斗'),
          ('04-attack-raise-v02', '01 举弩 · 修正候选'), ('05-attack-aim-v02', '02 瞄准 · 仍有残肢'),
          ('06-attack-release-v02', '03 击发 · 试验帧'), ('07-attack-recover', '04 收势')]
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 24)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 17)

def tile(path, label, width=360, height=560):
    canvas = Image.new('RGB', (width, height), '#e3e0d6')
    draw = ImageDraw.Draw(canvas)
    for y in range(45, height, 20):
        for x in range(0, width, 20):
            if ((y-45)//20 + x//20) % 2:
                draw.rectangle((x, y, x+19, y+19), fill='#d5d4cb')
    if path.exists():
        im = Image.open(path).convert('RGBA')
        im.thumbnail((width-24, height-68), Image.Resampling.LANCZOS)
        canvas.paste(im, ((width-im.width)//2, 53+(height-68-im.height)//2), im)
    draw.text((14, 10), label, font=font, fill='#23302e')
    return canvas

files = [(key, name, ROOT/key/'output.png') for key, name in LABELS]
missing = [key for key, _, path in files if not path.exists()]
if missing:
    raise RuntimeError('Missing outputs: ' + ', '.join(missing))
overview = Image.new('RGB', (1080, 620), '#eeeae1')
ImageDraw.Draw(overview).text((18, 10), 'Qwen-Image-2.1 / 阿棠 / 本地评估候选', font=font, fill='#23302e')
for i, (_, name, path) in enumerate(files[:3]):
    overview.paste(tile(path, name), (i*360, 55))
overview.save(ROOT/'character-overview.jpg', quality=94)
attack = Image.new('RGB', (1440, 620), '#eeeae1')
ImageDraw.Draw(attack).text((18, 10), '独立生成的四张动作关键帧 · 不是连续视频或已验收精灵动画', font=font, fill='#23302e')
for i, (_, name, path) in enumerate(files[3:]):
    attack.paste(tile(path, name), (i*360, 55))
attack.save(ROOT/'attack-keyframes.jpg', quality=94)
gif_frames = [tile(path, name, 512, 768) for _, name, path in files[3:]]
gif_frames[0].save(ROOT/'keyframe-flipbook.gif', save_all=True, append_images=gif_frames[1:], duration=[450,650,350,650], loop=0)
stats = []
for key, name, path in files:
    im=Image.open(path)
    alpha=im.getchannel('A') if im.mode=='RGBA' else None
    stats.append({'id':key, 'label':name, 'size':im.size, 'mode':im.mode,
                  'alpha_extrema':alpha.getextrema() if alpha else None})
(ROOT/'image-stats.json').write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding='utf-8')
h3 = '../combat-shoot-E-v02/originals/11/source_00001.mp4'
cards=''.join(f'<figure><a href="{key}/output.png"><img src="{key}/output.png"></a><figcaption>{name}</figcaption></figure>' for key,name,_ in files)
html='''<!doctype html><meta charset="utf-8"><title>阿棠 · Qwen 2.1 本地评估</title>
<style>body{font:16px system-ui;background:#242927;color:#eee7d6;max-width:1400px;margin:32px auto;padding:0 24px}h1{font-size:26px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}figure{margin:0;background:#393e3a;padding:12px}img{max-width:100%;max-height:640px;display:block;margin:auto;background:repeating-conic-gradient(#888 0% 25%,#999 0% 50%) 50%/24px 24px}figcaption{padding:10px}video{width:440px;max-width:100%}a{color:#b6d5d2}.compare{display:flex;gap:24px;flex-wrap:wrap}.compare img{height:520px}p{line-height:1.7}</style>
<h1>阿棠 · Qwen-Image-2.1 本地评估</h1><p>标准版官方 INT8 · 30 步 · 原始生成结果保留。所有图都是评估候选，未接入游戏。点击图片查看原图。</p><p><strong>动作试验未通过：</strong>初版出现重复手臂和双弩；定向修正后仍有腰部残肢、纸张残留，弩弦释放状态尚不可靠。图片清晰度不能代替动画连贯性。</p>
<div class="grid">'''+cards+'''</div><h2>动作连贯性检查</h2><p>左侧仅为四张独立图片按固定时长翻页，无补帧；右侧是已有 H3 原始 24 fps 视频。两者参考输入和生成方式不同，不是受控性能评测。</p><div class="compare"><figure><img src="keyframe-flipbook.gif"><figcaption>Qwen 独立关键帧翻页</figcaption></figure><figure><video controls loop muted src="'''+h3+'''"></video><figcaption>已有 H3 射击原视频（保留原绿幕及生成的箭光）</figcaption></figure></div><p>重点：同一张脸、衣服、握点、弩的结构、视角、脚底位置；不能用四张好看的图推断连续动画质量。</p>'''
html += '<h2>原始失败结果与修正记录</h2><p>这些图没有被删除或掩盖。左侧初版重复了手臂和弩；修正版本仍有残留。</p><img src="attack-initial-review.jpg"><img src="attack-correction-review.jpg"><p><a href="01-portrait/output.png">首张偏题的全身图</a> · <a href="03-combat-ready/output.png">最初持弩图</a> · <a href="03-combat-ready-v02/output.png">第一次持弩修正</a></p>'
(ROOT/'index.html').write_text(html, encoding='utf-8')
print(ROOT/'index.html')
