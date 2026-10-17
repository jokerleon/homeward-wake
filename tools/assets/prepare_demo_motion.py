"""Write one reviewable H3 recipe. Does not submit jobs or modify source art."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWS = {
    'S': 'directly toward the viewer, FRONT view',
    'SE': 'toward the viewer and to the viewer\'s right in world depth, FRONT-RIGHT three-quarter view (yaw only, never aim down at the floor)',
    'E': 'toward screen RIGHT, exact RIGHT SIDE profile',
    'NE': 'away from the viewer and to the viewer\'s right in world depth, BACK-RIGHT three-quarter view (yaw only, never aim up into the sky)',
    'N': 'straight away from the viewer, REAR view',
}
SHARED = (
    ' Animate exactly the ONE supplied character and unchanged costume, face, hair and props. '
    'Keep the source camera/view/scale fixed for the entire clip. Full hair, boots and entire weapon '
    'stay inside broad canvas margins. Orthographic game sprite camera, pure flat bright green '
    'chroma background with no floor or shadow. No scenery, other people, cuts, text, zoom, spin, '
    'flashes, motion trails, projectiles, smoke or camera movement. Clean painted color masses, '
    'no added dirt or decorative fabric patterns. Root stays in one small ground area.'
)


def action_prompt(action, state, direction):
    view = VIEWS[direction]
    facing = ' Facing ' + view + ' throughout. Never rotate toward another view.'
    if action == 'move' and state == 'explore':
        return (
            'EMPTY-HANDED normal walking animation. Hands stay empty, no combat weapon appears. '
            'Begin in the relaxed supplied stance for a brief moment, take four ordinary walking '
            'steps IN PLACE with alternating feet and natural opposite arm swing, then settle '
            'back to the supplied relaxed stance. Comfortable upright posture, natural grounded '
            'heel and toe contacts, small body bob, not running or combat crouching.' + facing + SHARED
        )
    if action == 'move':
        return (
            'BENT-KNEE COMBAT FOOTWORK, controlled low advance. Maintain the exact low hip height '
            'and forward torso angle of the supplied guarded stance. The head NEVER rises above '
            'its starting height. Both knees remain visibly bent. Take a short step with the lead '
            'foot, then bring the rear foot forward a little, keeping feet separated and one foot '
            'always planted. Repeat this compact lead-and-follow footwork smoothly twice IN PLACE, '
            'then stop in the original guard. No crossed feet, high knees, bouncing, flight phase, '
            'run, upright walk, deep stealth squat or turning. Keep upper body controlled and the '
            'existing weapon rigidly held ready, with the same grip throughout.' + facing + SHARED
        )
    if action == 'shoot':
        return (
            'A short mechanical AIM-AND-RESET rehearsal with the supplied wooden crossbow. '
            'In one fluid compact action, lift the existing crossbow to eye-line, brace the wrists '
            'and aim at an equal-height opponent along the body heading in the ground plane. '
            'The bow remains physically level; front and rear views use depth foreshortening, '
            'not a prescribed diagonal screen angle or weapon pitch. Keep the rail empty, '
            'with no visible bolt or arrow shaft. Hold the aim '
            'briefly, flex the right index finger once on its small lever, then lower it back '
            'to the starting hold. This is a quiet rehearsal of body motion. The flat green space '
            'around the character remains completely unchanged and empty in every frame. '
            'Both perpendicular wooden bow limbs and the tension string keep their exact source '
            'shape throughout. Feet remain planted, hips low and knees bent, same two-handed grip. '
            'Finish promptly in the original guard. No extra action or new object.' + facing + SHARED
        )
    if action == 'reload':
        return (
            'One readable compact wooden CROSSBOW RELOAD. From the supplied low ready stance, '
            'lower and brace the same crossbow, bring the free hand to the center of the string, '
            'pull it firmly back to the latch, briefly reach toward the belt pouch and return '
            'the empty hand over the rail, then resume the original two-handed ready hold. '
            'Only body and mechanism motions: no visible bolt or arrow appears. Deliberate '
            'distinct hand actions, modest body weight shift, feet planted and knees bent. '
            'No shooting, no projectile, no rifle magazine, no pump action or invented mechanism.' + facing + SHARED
        )
    if action == 'attack':
        return (
            'One clear saber combat attack. Begin in the supplied bent-knee guard. Draw the '
            'already-held saber arm slightly back, step a short distance forward and make ONE '
            'decisive cutting slash toward screen right, then recover into the exact original '
            'guard. Keep the same visible blade, grip and handedness, natural planted support '
            'foot and modest hip rotation. No full spin, second attack, acrobatics or release '
            'of the saber. No slash trail, flash, blood or impact effect.' + facing + SHARED
        )
    if action == 'heavy':
        return (
            'One clearly telegraphed heavy saber attack. From the bent-knee guard, firmly brace '
            'both feet, raise the same saber above the right shoulder and hold this threat for '
            'one full second. Then perform ONE powerful downward diagonal cut toward screen '
            'right with a short step and settle back to guard. Readable windup, cut and recovery; '
            'no spin, jump, extra attack, slash trail, blood, flash or impact effect.' + facing + SHARED
        )
    if action == 'hit-down':
        return (
            'Two clearly separated non-graphic combat reactions, no attacking. First remain '
            'in the supplied guard briefly. In the first two seconds, flinch once as if hit '
            'in the torso, lean back and return fully to the initial guarded stance. Hold '
            'that recovered stance for half a second. Then knees buckle, sink onto one knee '
            'and fall sideways onto the ground, ending still and defeated. Keep the same '
            'weapon visible; it lowers safely with the body. No blood, wounds, dismemberment, '
            'lightning, hit spark, second person, camera change or disappearing body.' + facing + SHARED
        )
    if action == 'gesture':
        return (
            'A quiet rescued shipwright dialogue performance. Start in the supplied relaxed '
            'standing pose, breathe naturally, nod once, raise one empty hand in a small '
            'grateful conversational gesture, then lower it to the initial relaxed stance. '
            'Keep the same age and gentle face, shoulders relaxed, boots planted. The small '
            'hammer stays on the belt; no weapon, walking, lip-synced speech or exaggerated acting.' + facing + SHARED
        )
    raise ValueError(action)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--character', required=True)
    parser.add_argument('--state', choices=['explore', 'combat'], required=True)
    parser.add_argument('--action', choices=['move', 'shoot', 'reload', 'attack', 'heavy', 'hit-down', 'gesture'], required=True)
    parser.add_argument('--direction', choices=list(VIEWS), default='E')
    parser.add_argument('--source', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--seed', type=int, required=True)
    args = parser.parse_args()
    assert (ROOT / args.source).is_file()
    extraction = (ROOT / args.source).parent / 'extraction.json'
    if extraction.is_file():
        entry = next(item for item in json.loads(extraction.read_text(encoding='utf-8'))['directions'] if item['file'] == Path(args.source).name)
        assert entry.get('source_edge_pixels', 0) == 0, 'Original source touches the sheet edge; inspect and repair with imagegen before H3.'
    name = f'{args.state}-{args.action}-{args.direction}-{args.version}'
    output = f'Assets/Characters/Working/{args.character}/{name}'
    folder = ROOT / output
    recipe = {
        'id': args.character.lower() + '-' + name, 'kind': 'motion', 'output': output,
        'endpoint': 'http://127.0.0.1:8196', 'model': 'minimax_h3_fl2va_pruned_int8_convrot.safetensors',
        'canvas': [768, 768], 'frames': {'shoot': 39, 'attack': 39, 'reload': 90, 'heavy': 90, 'hit-down': 124}.get(args.action, 73),
        'steps': 20, 'seed': args.seed, 'task_type': 'FL2VA' if args.action != 'hit-down' else 'I2VA', 'references': [args.source],
        'end_matches_start': args.action != 'hit-down',
        'trim_reference_transparency': False, 'reference_background': [0, 255, 0],
        'reference_max_size': 640, 'prompt': action_prompt(args.action, args.state, args.direction),
    }
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / 'recipe.json'
    if path.exists():
        assert json.loads(path.read_text(encoding='utf-8')) == recipe, 'Existing recipe differs; create a new version.'
    else:
        path.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(path.relative_to(ROOT).as_posix())


if __name__ == '__main__':
    main()
