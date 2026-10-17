"""Bounded local ComfyUI H3 jobs with immutable submission receipts.

Uses only the existing loopback service. It never downloads models, modifies the
external installation, calls a cloud generation provider, or retries a submission.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import time
import urllib.error
import urllib.request
import urllib.parse
import uuid

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
COMFY = Path(r'D:\Work\AI\Video\minimax\Comfyui-WF-2026.8.8\ComfyUI')
BASE = 'http://127.0.0.1:8188'

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def get(route):
    return json.load(urllib.request.urlopen(BASE + route, timeout=15))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def recipe_folder(recipe_path):
    recipe = json.loads(recipe_path.read_text(encoding='utf-8-sig'))
    folder = (ROOT / recipe['output']).resolve()
    permitted = [ROOT / 'Assets/Characters/Working', ROOT / 'Assets/HarborTrial/demo/Working']
    assert any(folder.is_relative_to(path.resolve()) for path in permitted), folder
    return recipe, folder

def prepare(recipe_path):
    recipe, folder = recipe_folder(recipe_path)
    if recipe['kind']!='motion':
        raise SystemExit('User correction: imagegen produces images; local H3 is video-only. Historical still jobs remain collectible.')
    if (folder / 'submission-started.json').exists():
        raise SystemExit('Submission marker exists; collect this job, never rebuild or resubmit it.')
    folder.mkdir(parents=True, exist_ok=True)
    references=[]
    input_root=COMFY/'input'/'chess-return-demo-20261010'
    input_root.mkdir(parents=True,exist_ok=True)
    for i,value in enumerate(recipe.get('references', []),1):
        source=(ROOT/value).resolve()
        assert source.is_relative_to(ROOT) and source.is_file(),source
        original=Image.open(source).convert('RGBA')
        # Source preparation retains the full figure. This is not the delivered
        # dialogue portrait; H3 must author that separately with a new composition.
        alpha_threshold=int(recipe.get('reference_alpha_threshold',0))
        bounds=original.getchannel('A').point(lambda value:255 if value>alpha_threshold else 0).getbbox()
        if bounds and recipe.get('trim_reference_transparency', True):
            original=original.crop(bounds)
        reference_size=int(recipe.get('reference_max_size',704))
        assert 384<=reference_size<=704
        original.thumbnail((reference_size,reference_size), Image.Resampling.LANCZOS)
        background=recipe.get('reference_background',[225,222,208])
        canvas=Image.new('RGBA',(768,768),tuple(background)+(255,))
        canvas.alpha_composite(original,((768-original.width)//2,(768-original.height)//2))
        name=recipe['id']+f'-ref-{i:02d}.png'
        prepared=folder/name
        canvas.convert('RGB').save(prepared)
        shutil.copy2(prepared,input_root/name)
        references.append({'original':str(source.relative_to(ROOT)).replace('\\','/'),'original_sha256':sha(source),'prepared':name,'prepared_sha256':sha(prepared),'comfy_input':'chess-return-demo-20261010/'+name})
    width,height=recipe['canvas']
    assert width%32==0 and height%32==0
    def node(kind,inputs,title):return {'class_type':kind,'inputs':inputs,'_meta':{'title':title}}
    graph={
        '1':node('UNETLoader',{'unet_name':recipe['model'],'weight_dtype':'default'},'Local H3 model'),
        '2':node('CLIPLoader',{'clip_name':'qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors','type':'minimax','device':'default'},'Local H3 text / reference encoder'),
        '3':node('VAELoader',{'vae_name':'minimax_h3_video_vae_fp16.safetensors'},'Local H3 video VAE'),
    }
    for i,ref in enumerate(references):
        graph[str(20+i)]=node('LoadImage',{'image':ref['comfy_input']},f'Reference {i+1}')
    if recipe['kind']=='still':
        assert references,'Reference still generation needs a primary image.'
        conditioning={'clip':['2',0],'video_vae':['3',0],'prompt':recipe['prompt'],'canvas_mode':'custom','width':width,'height':height,'target_mode':recipe.get('target_mode','short_video_22_frames'),'reference_strength':0.999,'audio_target':'generate_and_discard','strict_prompt_tags':True,'ref_image_size':'match','edit_image':['20',0]}
        for i in range(1,len(references)):
            conditioning[f'ref_images.ref_image_{i-1}']=[str(20+i),0]
        graph['5']=node('MiniMaxH3StillConditioningT8',conditioning,'Independent illustrated still candidate')
    else:
        graph['4']=node('VAELoader',{'vae_name':'minimax_h3_audio_vae_fp32.safetensors'},'Local H3 audio VAE')
        conditioning={'clip':['2',0],'video_vae':['3',0],'audio_vae':['4',0],'prompt':recipe['prompt'],'width':width,'height':height,'length':recipe.get('frames',124),'task_type':recipe.get('task_type','I2VA'),'audio_mode':'native','audio_denoise_strength':1.0,'add_source_as_reference':False,'prompt_primary_audio_ordinal':0,'strict_prompt_tags':True,'ref_image_size':'match','reference_video_policy':'official_2_to_15s'}
        if references:
            conditioning['first_frame']=['20',0]
            if recipe.get('end_matches_start'):conditioning['last_frame']=['20',0]
        graph['5']=node('MiniMaxH3AudioConditioningT8',conditioning,'Single fixed-camera character action')
    graph.update({
        '6':node('MiniMaxH3DualClockSamplerT8',{'model':['1',0],'av_latent':['5',1],'steps':recipe.get('steps',20),'shift_video':12.0,'shift_audio':3.0,'sampler_name':'dual_clock_euler','scheduler':'native_flow'},'Native H3 dual-clock sampling; no turbo LoRA'),
        '7':node('RandomNoise',{'noise_seed':recipe['seed']},'Recorded seed'),
        '8':node('BasicGuider',{'model':['6',0],'conditioning':['5',0]},'H3 conditioning'),
        '9':node('SamplerCustomAdvanced',{'noise':['7',0],'guider':['8',0],'sampler':['6',1],'sigmas':['6',2],'latent_image':['5',1]},'Generate one candidate'),
    })
    prefix='chess-return-demo-20261010/'+recipe['id']
    if recipe['kind']=='still':
        graph['10']=node('MiniMaxH3StillDecodeT8',{'av_latent':['9',0],'video_vae':['3',0],'frame_selection':'middle','frame_index':0},'Select independent portrait / art candidate')
        graph['11']=node('SaveImage',{'images':['10',0],'filename_prefix':prefix+'/selected'},'Save selected original image')
        graph['12']=node('SaveImage',{'images':['10',1],'filename_prefix':prefix+'/context'},'Preserve all generated candidate frames')
    else:
        graph['10']=node('MiniMaxH3AVDecodeT8',{'av_latent':['9',0],'video_vae':['3',0],'audio_vae':['4',0]},'Decode original source frames')
        graph['11']=node('VHS_VideoCombine',{'images':['10',0],'frame_rate':24.0,'loop_count':0,'filename_prefix':prefix+'/source','format':'video/h264-mp4','pingpong':False,'save_output':True,'pix_fmt':'yuv420p','crf':16,'save_metadata':True,'trim_to_audio':False},'Save original 24 fps source video')
        graph['12']=node('SaveImage',{'images':['10',0],'filename_prefix':prefix+'/frames'},'Preserve decoded source frames')
    save(folder/'recipe.json',recipe)
    save(folder/'workflow-api.json',graph)
    save(folder/'source-provenance.json',references)
    save(folder/'production-record.json',{'id':recipe['id'],'status':'prepared','provider':'local-comfyui','endpoint':BASE,'created_at_unix':time.time(),'generation_api_spend_cny':0,'cost_note':'Local GPU execution; electricity and hardware cost not estimated. No external generation endpoint.','review':'Not reviewed or adopted.','user_authorization':'2026-10-10 user approved starting needed assets and keeping the current ship.'})
    print(json.dumps({'status':'prepared','folder':str(folder),'node_count':len(graph)},ensure_ascii=False))

def submit(recipe_path):
    recipe,folder=recipe_folder(recipe_path)
    if recipe['kind']!='motion':
        raise SystemExit('User correction: do not submit still-image jobs to H3. Use built-in imagegen.')
    assert (folder/'workflow-api.json').is_file(),'Prepare first.'
    if (folder/'submission-started.json').exists() or (folder/'submission.json').exists():
        raise SystemExit('Job was already submitted or outcome is uncertain; collect it instead.')
    queue=get('/queue')
    if queue.get('queue_running') or queue.get('queue_pending'):
        raise SystemExit('Local queue is occupied; do not interfere or add a batch.')
    client='chess-return-demo-'+str(uuid.uuid4())
    graph=json.loads((folder/'workflow-api.json').read_text(encoding='utf-8'))
    body={'prompt':graph,'client_id':client,'extra_data':{'asset_id':recipe['id'],'project':'return-home-demo','recipe_sha256':sha(folder/'recipe.json')}}
    save(folder/'submission-started.json',{'started_at_unix':time.time(),'client_id':client,'id':recipe['id'],'workflow_sha256':sha(folder/'workflow-api.json')})
    request=urllib.request.Request(BASE+'/prompt',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
    try:
        response=json.load(urllib.request.urlopen(request,timeout=30))
    except urllib.error.HTTPError as error:
        raw=error.read().decode('utf-8','replace')
        try:rejection=json.loads(raw)
        except ValueError:rejection={'message':raw}
        save(folder/'submission-rejected.json',rejection)
        print(json.dumps(rejection,ensure_ascii=False))
        raise SystemExit('Validation rejected the job; no automatic retry.')
    save(folder/'submission.json',response)
    print(json.dumps(response,ensure_ascii=False))

def collect(recipe_path):
    recipe,folder=recipe_folder(recipe_path)
    receipt=json.loads((folder/'submission.json').read_text(encoding='utf-8'))
    job_id=receipt['prompt_id']
    try:
        history=get('/history/'+job_id).get(job_id)
    except urllib.error.URLError:
        return collect_offline(recipe,folder,job_id)
    if not history:
        queue=get('/queue')
        print(json.dumps({'id':recipe['id'],'prompt_id':job_id,'running':any(x[1]==job_id for x in queue.get('queue_running',[])),'pending':any(x[1]==job_id for x in queue.get('queue_pending',[]))}))
        return
    save(folder/'history.json',history)
    outputs=[]
    for node_id,output in history.get('outputs',{}).items():
        for field in ['images','gifs']:
            for item in output.get(field,[]):
                if item.get('type') not in ['output','temp']:continue
                source=(COMFY/item['type']/item.get('subfolder','')/item['filename']).resolve()
                assert source.is_relative_to((COMFY/item['type']).resolve())
                if not source.is_file():continue
                directory=folder/'originals'/node_id
                directory.mkdir(parents=True,exist_ok=True)
                target=directory/source.name
                if target.exists():
                    assert sha(target)==sha(source),'Existing original differs; preserve both instead of overwriting.'
                else:shutil.copy2(source,target)
                outputs.append({'node':node_id,'file':str(target.relative_to(folder)).replace('\\','/'),'bytes':target.stat().st_size,'sha256':sha(target)})
    status=history.get('status',{})
    events={name:data.get('timestamp') for name,data in status.get('messages',[]) if isinstance(data,dict)}
    elapsed=(events['execution_success']-events['execution_start'])/1000 if events.get('execution_success') and events.get('execution_start') else None
    errors=[data for name,data in status.get('messages',[]) if name in ['execution_error','execution_interrupted']]
    result={'id':recipe['id'],'prompt_id':job_id,'status':status.get('status_str'),'completed':status.get('completed'), 'seconds':elapsed,'outputs':outputs,'errors':errors}
    save(folder/'result.json',result)
    print(json.dumps({**result,'outputs':[{'node':x['node'],'file':x['file']} for x in outputs][:5],'output_count':len(outputs)},ensure_ascii=False))


def collect_offline(recipe,folder,job_id):
    """Recover completed local outputs after ComfyUI exits; never submit a job."""
    source=COMFY/'output'/'chess-return-demo-20261010'/recipe['id']
    frames=sorted(source.glob('frames_*.png'))
    movies=sorted(source.glob('source_*.mp4'))
    if not frames or len(movies)!=1:
        raise SystemExit('Service unavailable and complete unique output is not proven. Preserve submission and do not resubmit.')
    workflow=json.loads((folder/'workflow-api.json').read_text(encoding='utf-8'))
    def semantic(graph):
        return {key:{'class_type':node['class_type'],'inputs':node['inputs']} for key,node in graph.items()}
    expected=semantic(workflow)
    for frame in frames:
        embedded=json.loads(Image.open(frame).info.get('prompt','{}'))
        assert semantic(embedded)==expected,'Output workflow differs; do not adopt.'
    assert len(frames)>=recipe.get('frames',124),'Incomplete source frame sequence; preserve uncertain outcome.'
    outputs=[]
    for node,files in [('11',movies),('12',frames)]:
        destination=folder/'originals'/node;destination.mkdir(parents=True,exist_ok=True)
        for path in files:
            target=destination/path.name
            if target.exists():assert sha(target)==sha(path),'Existing original differs; preserve both.'
            else:shutil.copy2(path,target)
            outputs.append({'node':node,'file':str(target.relative_to(folder)).replace('\\','/'),'bytes':target.stat().st_size,'sha256':sha(target)})
    result={'id':recipe['id'],'prompt_id':job_id,'status':'success_recovered_from_local_outputs','completed':True,'requested_frames':recipe.get('frames',124),'actual_lossless_frames':len(frames),'outputs':outputs,'seconds':None,'recovery':'Local service unavailable. Unique output prefix and every embedded node class/input match the immutable submitted workflow. Runtime-only is_changed metadata is ignored. All original outputs preserved. No live history, timing claim or resubmission.'}
    save(folder/'result.json',result)
    print(json.dumps({key:value for key,value in result.items() if key!='outputs'},ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['prepare','submit','collect'])
    parser.add_argument('recipe',type=Path)
    args=parser.parse_args()
    configured=json.loads(args.recipe.read_text(encoding='utf-8-sig')).get('endpoint',BASE)
    endpoint=urllib.parse.urlsplit(configured)
    assert endpoint.scheme=='http' and endpoint.hostname in ['127.0.0.1','localhost'] and not endpoint.username and not endpoint.password and not endpoint.path
    BASE=configured
    {'prepare':prepare,'submit':submit,'collect':collect}[args.action](args.recipe.resolve())
