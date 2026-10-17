"""Submit and collect isolated Qwen 2.1 character evaluation jobs via ComfyUI."""
import argparse
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone
import requests

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / 'Assets/Characters/Working/Atang/qwen21-eval-v01'
BASE = 'http://127.0.0.1:8191'
REF = PROJECT / 'Assets/Characters/Working/Atang/portrait-clean-v03/atang-dialogue.png'
WEAPON = PROJECT / 'Assets/Characters/Working/Atang/armed-design-v01/atang-crossbow-design.png'

IDENTITY = '保持参考人物阿棠的同一张脸、黑色高马尾和赭黄发带、海青色交领短衣、米白领口和卷袖、锈橙腰带、深蓝裤子、绑腿与靴子。小工具袋固定在腰侧。保持清晰色块、自然皮肤、克制的手绘明暗、干净布料；不添加密集花纹、污渍或颗粒。'
POSE = '单人完整全身，头发、双脚、整个武器全部在画面内，周围留足空间。固定游戏相机，轻微俯视，人物严格正右侧面，身体和脸都朝画面右方，不回头看镜头。髋部略低，双膝微弯，躯干适度前倾，稳定战斗姿态，不是深蹲或潜行。'
TRANSPARENT = '输出真正有透明通道的RGBA人物素材，背景透明，没有地面、场景、光晕、投影、文字、边框或其他人物。'
SPECS = {
    '01-portrait': {'refs': [REF], 'prompt': '依据参考图制作同一人物的独立半身对话立绘，从头顶到腰部，双手自然放松，神情机敏友善，头发完整。手中不拿纸张或工具。' + IDENTITY + TRANSPARENT},
    '01-portrait-v02': {'refs': [REF], 'prompt': '将参考图重构为近景半身人物肖像：镜头拉近，画面只显示完整头顶、头发、脸、肩膀、胸部和腰带，画面下缘截止在腰带处，腿和脚全部位于画面外。人物的脸占画面高度约四分之一。保持参考图中阿棠的同一张脸、黑色高马尾和赭黄发带、友善神情、海青色交领短衣、米白领口卷袖及锈橙腰带。移除纸张，让双手放松在腰前。保持干净清晰的手绘色块、自然皮肤和简洁衣褶。半身近景构图，不是全身立绘。' + TRANSPARENT},
    '02-explore': {'refs': [REF], 'prompt': '依据参考图制作同一人物在港口探索时使用的全身游戏角色素材。单人完整全身，轻微俯视游戏相机，朝画面右方的三分之二侧面，自然站立，双手空着并放松，不拿纸张、工具、弩或任何武器。补全宽松深蓝裤、绑腿和靴子。' + IDENTITY + TRANSPARENT},
    '03-combat-ready': {'refs': [REF, WEAPON], 'prompt': '<image1>提供人物的脸、发型、干净手绘风格和海青色服装；<image2>仅提供木制单发轻弩的外观、结构与握持关系，不采用它的脏旧布料或背景。制作阿棠战斗待机全身素材。' + IDENTITY + POSE + '双手在胸腹前稳定握住同一把轻弩，右手握扳机处、左手托弩身前部，弩口朝右，略低于瞄准位置。纸张收好。' + TRANSPARENT},
    '03-combat-ready-v02': {'refs': ['03-combat-ready'], 'prompt': '只做两项明确修改：一、彻底移除胸前和手臂下的所有白色纸张，那里只保留海青色上衣和木制弩；二、将整个角色和弩转成严格朝画面右方的正侧面，鼻尖指向右侧，画面只看到侧脸的一只眼睛，视线水平看右方而不是看观众。保持同一张脸、同一发型服装、同一把弩、双手握持点、微屈膝战斗站姿、人物尺度和完整全身构图。不要新增装备或改变弩的机械结构。' + TRANSPARENT},
    '03-combat-ready-v03': {'refs': ['03-combat-ready-v02'], 'prompt': 'Remove the two large ivory paper sheets trapped between her torso and crossbow. The ivory triangle above the wooden stock and the ivory quadrilateral below her right forearm are loose PAPER, not sleeves. Replace only those two paper regions with the teal jacket and rust-orange waist sash that are behind them. Keep her rolled ivory cuffs at the elbows. Preserve her entire pose, face, hair, both hands, the complete rigid crossbow, all clothing, canvas, scale and transparent alpha. This is a small local object removal. Do not add any new object.'},
    '04-attack-raise': {'refs': ['03-combat-ready'], 'prompt': '这是参考角色同一次向画面右方射弩动作的举弩准备帧。保持同一个人、服装、武器、相机、人物尺寸、脚的位置和透明背景，只改变手臂姿态：双手将弩从腹前举至胸口，枪托接近右肩，弩口保持朝右。髋部略低、膝盖微弯、躯干微前倾，视线看右侧目标。整个弩保持刚性，不增减弓臂或弦，无飞行箭、烟火、特效。' + TRANSPARENT},
    '05-attack-aim': {'refs': ['03-combat-ready'], 'prompt': '这是参考角色同一次向画面右方射弩动作的稳定瞄准帧。保持同一个人、脸、衣装、武器、相机、人物尺寸、脚的位置和透明背景。双手把同一把弩举到肩部高度，弩托贴右肩，右手握扳机，左手托弩身，头略贴近瞄准线，目视右侧，弩口水平朝右。双膝微弯，重心稳定。整个武器刚性完整，没有烟火或飞行箭。' + TRANSPARENT},
    '06-attack-release': {'refs': ['05-attack-aim'], 'prompt': '把参考图改为扣动弩机后的瞬间。严格保持相机、人物位置与大小、服装、双脚、双手握持点和弩的全部形状，仅右手食指扣动扳机，弩弦已从蓄力位置回到前方放松位置，弩槽内不再有箭。头和上身保持稳定，仅非常轻微的释放反馈，不出现枪械式大后坐。人物继续瞄准右方，不转身、不移动，不绘制飞行箭、火光、烟雾或光效。' + TRANSPARENT},
    '07-attack-recover': {'refs': ['03-combat-ready'], 'prompt': '这是参考角色向右射弩后收势的动作帧。保持同一个人、服装、弩的结构、相机、人物尺寸、双脚位置和透明背景。双手将发射后的弩从肩部下放到胸腹之间，弩口略向下但仍朝右，肩部略放松，视线继续看右方。双膝微弯。弩上没有装填的新箭，弩弦处于发射后状态。没有烟火、飞行箭或文字。' + TRANSPARENT},
}
for key in ['04-attack-raise', '05-attack-aim', '07-attack-recover']:
    SPECS[key]['refs'] = ['03-combat-ready-v03']
SPECS['04-attack-raise-v02'] = {
    'refs': ['03-combat-ready-v03'],
    'prompt': 'Repose the existing woman as she raises her ONE crossbow from waist level toward her shoulder. MOVE her existing two arms and existing crossbow; erase their old waist-level positions completely. There must be exactly TWO arms, TWO hands, and ONE crossbow in the entire image. Her right hand stays on the trigger grip and her left hand supports the forward stock. The crossbow is now at upper-chest height, pointing screen right. Both elbows bend naturally to support it. Where the former arms and weapon were, show only her teal shirt. Remove the loose ivory paper sheets. Keep the same woman, hair, face, clothes, legs, feet, image framing, and transparent RGBA background. Single character, single instant, no motion trails, no ghost limbs, no overlay poses.'}
SPECS['05-attack-aim-v02'] = {
    'refs': ['03-combat-ready-v03'],
    'prompt': 'Replace the existing arm pose with a proper crossbow aiming pose. The woman holds her ONE wooden crossbow at shoulder height, stock against her right shoulder, cheek near the stock, looking along the weapon toward screen right. Her right hand grips the trigger, her left hand supports the stock. MOVE the original arms upward: remove both original waist-level arms and remove the old waist-level weapon entirely. Exactly two arms, two hands and one crossbow are visible, no duplicates. Show her uninterrupted teal jacket across the waist where the old arms were. Remove all loose ivory paper sheets. Keep the same face, hair, costume, bent-knee leg stance, feet, canvas and transparent RGBA background. Single instant of a single character.'}
SPECS['06-attack-release-v02'] = {
    'refs': ['05-attack-aim-v02'],
    'prompt': 'Show the instant just AFTER this woman fires the ONE wooden crossbow. Preserve the two-arm aiming pose, same two hands and one weapon, same character, camera and feet. Her trigger finger has squeezed the trigger; the bolt has left the weapon and is not visible anywhere; the string is now at the forward released position. Very small natural follow-through in her shoulders, no firearm recoil. Do not add any arm, hand, weapon, projectile or effect. This is one single moment, not an overlay of before and after poses. Preserve transparent alpha.'}

def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

def submit(name):
    folder = ROOT / name
    folder.mkdir(parents=True, exist_ok=True)
    if (folder / 'submission.json').exists():
        raise RuntimeError('Existing submission: collect it, do not submit again.')
    spec = SPECS[name]
    graph = {
        '1': {'class_type': 'UNETLoader', 'inputs': {'unet_name': 'qwen_image_2.1_int8_convrot.safetensors', 'weight_dtype': 'default'}},
        '2': {'class_type': 'CLIPLoader', 'inputs': {'clip_name': 'qwen3vl_8b_int8_convrot.safetensors', 'type': 'qwen_image', 'device': 'default'}},
        '3': {'class_type': 'VAELoader', 'inputs': {'vae_name': 'qwen_image_2.1_vae_bf16.safetensors'}},
        '4': {'class_type': 'TextEncodeQwenImage21', 'inputs': {'clip': ['2', 0], 'vae': ['3', 0], 'prompt': spec['prompt'], 'negative_prompt': '', 'resolution': 1024}},
        '5': {'class_type': 'QwenImage21Cache', 'inputs': {'model': ['1', 0], 'device': 'auto', 'dtype': 'default'}},
        '6': {'class_type': 'KSampler', 'inputs': {'model': ['5', 0], 'positive': ['4', 0], 'negative': ['4', 1], 'latent_image': ['4', 2], 'seed': 2026101101, 'steps': 30, 'cfg': 1.0, 'sampler_name': 'euler', 'scheduler': 'simple', 'denoise': 1.0}},
        '7': {'class_type': 'VAEDecode', 'inputs': {'samples': ['6', 0], 'vae': ['3', 0]}},
        '8': {'class_type': 'SaveImage', 'inputs': {'images': ['7', 0], 'filename_prefix': 'qwen21-atang/' + name}},
    }
    provenance = []
    for i, ref in enumerate(spec['refs'], 1):
        source = ref if isinstance(ref, Path) else ROOT / ref / 'output.png'
        data = source.read_bytes()
        filename = f'qwen21-atang-{name}-ref{i:02d}.png'
        (folder / filename).write_bytes(data)
        response = requests.post(BASE + '/upload/image', files={'image': (filename, data, 'image/png')}, data={'overwrite': 'false'}, timeout=60)
        response.raise_for_status()
        uploaded = response.json()
        node_id = str(20 + i)
        graph[node_id] = {'class_type': 'LoadImage', 'inputs': {'image': uploaded['name']}}
        alpha_node_id = str(40 + i)
        graph[alpha_node_id] = {'class_type': 'JoinImageWithAlpha', 'inputs': {'image': [node_id, 0], 'alpha': [node_id, 1]}}
        graph['4']['inputs'][f'images.image_{i}'] = [alpha_node_id, 0]
        provenance.append({'source': str(source), 'copy': filename, 'sha256': hashlib.sha256(data).hexdigest()})
    dump(folder / 'workflow-api.json', graph)
    dump(folder / 'production-record.json', {'model': 'Qwen-Image-2.1', 'quantization': 'official Comfy-Org INT8 convrot', 'purpose': 'research/evaluation only, not adopted at runtime', 'prompt': spec['prompt'], 'references': provenance, 'utc': datetime.now(timezone.utc).isoformat()})
    response = requests.post(BASE + '/prompt', json={'prompt': graph, 'client_id': 'qwen21-atang-evaluation'}, timeout=60)
    result = response.json()
    dump(folder / ('submission.json' if response.ok else 'validation-error.json'), result)
    print(json.dumps(result, ensure_ascii=False))
    response.raise_for_status()

def collect(name):
    folder = ROOT / name
    submission = json.loads((folder / 'submission.json').read_text(encoding='utf-8'))
    response = requests.get(BASE + '/history/' + submission['prompt_id'], timeout=30)
    response.raise_for_status()
    history = response.json().get(submission['prompt_id'])
    if not history:
        print('RUNNING_OR_QUEUED', name)
        return
    dump(folder / 'history.json', history)
    if history.get('status', {}).get('status_str') == 'error':
        print(json.dumps(history['status'], ensure_ascii=False))
        return
    images = history.get('outputs', {}).get('8', {}).get('images', [])
    if not images:
        print('NO_OUTPUT_YET', name)
        return
    data = requests.get(BASE + '/view', params=images[0], timeout=60)
    data.raise_for_status()
    (folder / 'output.png').write_bytes(data.content)
    print('SAVED', folder / 'output.png')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['submit', 'collect'])
    parser.add_argument('name', choices=list(SPECS))
    args = parser.parse_args()
    (submit if args.mode == 'submit' else collect)(args.name)
