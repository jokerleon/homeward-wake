# Ming maritime HD-2D reboot — 2026-10-08

## Latest complete demo integration — 2026-10-13

- All four combatants now load their own combat packs. Captain and Guard use
  `runtime-combat-style-v06` Working publish specs, retaining the wine-red
  captain and ochre/charcoal/red-armband retainer. Do not regenerate these
  from old incomplete-state notes. User final art acceptance is still pending.
- Enemy locomotion is five source directions plus three mirrors; blade actions
  and reactions use E/W with side fallback. Captain heavy releases at authored
  time 1.916667 s; actual movement dodge and separate-bolt interruption passed.
- Preserve rejected Captain attack-v05 cyan trails and Guard NE-move-v04 root
  drift. Replacements are attack-v06 and NE-move-v05. All originals remain.
- Final 89.2 s GPU story: `Artifacts/ReturnDemo/all-cast-story-20261013`.
  Its integration receipt identifies current packs despite the old generic
  `report.json` source label. Flow 34, navigation 22 and default-battle matrix
  8 checks passed. The seven-item small-demo checklist is implemented/checked,
  not final visual approval or authorization to expand into the full game.
- Atang keeps 24 base damage and full reload. Un-suppressed default pursuit
  combat is close (hero 4 HP); this is not a guarantee for every deployment.
  Authored down poses use restrained 0.82 tint instead of legacy 0.5 darkness.

## Web setting discussion handoff — 2026-10-13

- User continues world/story discussion in the ChatGPT chat `游戏设定扩展`,
  ID `6acc98ac-d7a0-83ee-9efb-e91f24611138`. Read its latest user decisions
  when continuing lore work; do not send messages there without authorization.
- The user's stated preference there is an independent captain who can expand
  territory for Lin Qian's faction, explore and hunt treasure, with supernatural
  abilities/phenomena. Lin Qian advances his own effort to rescue the declining
  polity and change the dynasty; the player joins more freely.
- The reply's ten-year timeline, new names, institutions and detailed chapters
  are creative proposals, not blanket user approval. Keep the Gemini draft
  files intact and record conflicts separately. This does not authorize full
  world simulation or expansion beyond the current small demo.

## Latest setting handoff and deck readability — 2026-10-12

- User is developing world/story with Gemini and keeps evolving drafts in
  `docs/游戏设定/word_setting.md` and `role_setting.md`. Read those before new
  lore or cast production. Treat 大雍 and its places as original fiction; do not
  turn draft technical specs into approval to replace the accepted v03 art.
  Preserve these user-maintained files. Note conflicting tokens/appearances
  separately instead of silently choosing or rewriting a final canon.
- User explicitly chose to retain the current captain/retainer appearance
  while the setting drafts are unified. Keep the existing wine-red captain
  and yellow-brown/charcoal/red-armband retainer designs; do not adopt the new
  headscarf/lamellar or barefoot/fish-spear proposals from the draft yet.
- User accepts the shipmaster S gait and its mouth stability correction.
  Preserve them while continuing the remaining demo work.
- User reports dark deck combat actors. Current legacy stand-ins now use normal
  light weight, restrained fill and lifted painted midtones; the accepted port
  exploration materials and original v03 remain unchanged. Real comparison and
  1x recording: `Artifacts/ReturnDemo/deck-light-comparison-20261012` and
  `deck-light-final-20261012`. This is not completion of the new combat cast.

## Latest accepted walking motion and mouth correction — 2026-10-12

- User accepts the corrected shipmaster S walking action and reports flickering
  mouth detail. Preserve this accepted gait; do not regenerate the whole walk
  merely to fix the mouth. Walking-frame PNGs, timing and ground pivots stay fixed.
- The current correction uses head-tracked closed-mouth reference sampling in
  the renderer, restricted to the shipmaster's S exploration clips. It reuses
  the original idle atlas and does not redraw source frames or affect portraits.

## Latest front-walk correction — 2026-10-12

- User rejects shipmaster S/downward exploration walk: legs open and close
  sideways instead of alternating forward/back steps toward the viewer.
- Regenerate only this direction from a natural narrower stance. Keep each
  foot in its own parallel track; express advance/recovery through depth,
  foreshortening, alternating knee bend and heel/toe contact, not lateral
  abduction/adduction. Keep the compact ShenYan-style identity and fixed root.
- Preserve the rejected `Shipmaster/explore-move-S-style-v02` sources and
  continue the other authorized follow/UI work. Other directions are not
  rejected by this specific correction.

## Latest world-sprite, following and UI correction — 2026-10-11

- User rejects the current tall, bright shipmaster and Atang WORLD sprites as
  inconsistent with the scene; old ShenYan sprites are the required rendering
  style reference. Preserve character identities and independently authored
  dialogue portraits. New world art must use compact adult sprite proportions,
  restrained painted values and the v03 lighting response, with an actual
  same-scene comparison before expanding directions. Preserve rejected sources.
- Following must not repeatedly restart walk-start at its distance threshold.
  Use separate start/stop thresholds, match leader speed near the desired gap,
  and keep one start → continuous loop → one stop per genuine movement bout.
  Direction changes preserve gait phase; gameplay movement responds immediately.
  Study ShenYan's authored source seams, but do not assume v03 exercised them:
  v03 directly switches move_loop/idle rather than its full start/stop sequence.
- Game UI needs per-artwork nine-slice cuts, fixed corners, explicit content
  safe areas and container layout. Anchor HUD to viewport edges. Do not place
  text/icons independently over arbitrarily stretched backgrounds. Validate all
  dialogue/choice/deployment/order/pause states in actual Godot screenshots.

## Latest camera-relative aiming correction — 2026-10-11

- Map SE means facing toward the viewer and screen-right in ground-plane depth.
  It does not mean pitching the weapon toward the bottom-right of the image.
  At equal target height, aim level in world space and show the front-right view
  through foreshortening. NE likewise is yaw away/right, not upward weapon pitch.
- The `Atang/aimed-SE-v01` source and dependent `combat-shoot-SE-v03` recipe
  locked an incorrect down-right image angle. Preserve them, exclude from runtime,
  and replace with a depth-correct source before further SE shooting animation.

## Latest ranged-action clarification — 2026-10-11

- The user explicitly says ranged character animation does not need an arrow;
  body/weapon actions are sufficient. Keep character/crossbow motion arrow-free,
  including accidental generated arrow light or protruding arrow shafts.
- Godot spawns and moves the separate bolt at the authored release cue and owns
  collision and impact feedback. Preserve raw H3 outputs containing unwanted
  arrows for provenance, but exclude that imagery from runtime character frames.
- Eight-direction ranged facing and combat/exploration posture rules below still
  apply. Do not spend more generation effort merely to make H3 draw a projectile.

## Latest movement and ranged facing correction — 2026-10-11

- The user rejects the upright, leisurely weapon-bearing locomotion candidates.
  Combat idle/movement must use slightly lowered hips, bent knees, a modest
  forward torso lean and short purposeful advancing steps. Keep ranged upper-body
  and weapon control stable; melee movement uses a protective ready stance.
  Do not substitute a deep stealth crouch, exaggerated run or relaxed normal walk.
  Validate one corrected rightward sample before expanding directions. Preserve
  all rejected relaxed-combat source images/videos; do not adopt them at runtime.
- Exploration locomotion uses empty hands and does not display combat weapons.
  Weapon-bearing idle/movement belongs to combat scenes. Keep the explicitly
  requested waist-sheathed saber in the shipmaster's everyday dialogue portrait.
  Atang's already generated crossbow turnaround is COMBAT source only; create
  a separate unarmed exploration source rather than reusing it for port walking.
- Ranged attacks now require EIGHT directions: aiming, release, recovery and
  muzzle/bolt anchors must agree with the camera-relative target direction.
  This supersedes the earlier left/right-only recommendation for ranged attacks.
  Melee attacks remain RIGHT source plus mirrored LEFT. Preserve facing during
  a committed shot, and let Godot create and collide the actual projectile.

## Latest character-art correction — 2026-10-10

- Shipmaster's everyday/dialogue pose must show his saber fully sheathed and
  visibly suspended from his waist belt at his side, with relaxed empty hands.
  The ambiguous half-held, half-hanging weapon in the cast board is rejected.
  A drawn blade belongs only to combat-ready/attack states; preserve continuity.
- Further clarification: costumes, value/color groups, props and silhouettes
  must distinguish the shipmaster, Atang, Old Liang, the raider captain and his
  retainer. The user finds the current clean candidates too similar as a group.
  Develop a named cast comparison before expanding derived motion. Keep Atang's
  accepted face/hair identity. A comment about Old Liang being young was retracted:
  the user had mistaken another male character for him. Do not treat it as an
  instruction to age Old Liang further.
- The user asks to clean up and unify the existing characters, especially
  dialogue half-body portraits: remove dense dark patterns, mottled dirt,
  excessive grunge and noisy fabric texture. Use clear color masses, natural
  skin and readable folds with restrained painterly shading.
- Preserve each character's face, hairstyle, outfit silhouette and identity;
  this supersedes prior prompts that emphasized weathering or rich fabric noise.
  Atang's accepted identity still applies. Save clean revisions separately and
  retain all originals. Apply the cleaner rendering consistently to new portraits
  and world-source images before H3 video production.

## Latest execution scope — complete the agreed demo revision, 2026-10-10

- The user explicitly asks to implement ALL previously discussed adjustments,
  step by step, not just generate assets. Continue through navigation and group
  combat, camera/scale, character art/motion, graphical game UI, water/wakes,
  cannon feedback and integrated story-flow validation. Earlier analysis-only
  restrictions below are superseded within this small demo revision.
- Keep the current ship and the accepted v03 visual language. Images use built-in
  imagegen; video animation uses local H3. Preserve accepted portraits, original
  assets, receipts, rejected candidates and the original v03 entry.
- Do not stop after a plan or a partial asset batch. Track completion in
  `docs/DEMO_REVISION_IMPLEMENTATION_20261010.md`, verify the real game at normal
  speed, and report remaining limitations honestly. No full-game expansion,
  new ship procurement or unrelated-process troubleshooting is implied.

## Atang portrait accepted; weapon/action preparation — 2026-10-10

- The user accepted the new imagegen portrait in
  `Assets/Characters/Working/Atang/portrait-master-v01/atang-portrait.png`.
  Keep its face, hair, outfit and painted style as her visual identity baseline.
  Do not ask again for approval of the already accepted portrait.
- The user now requests thoughtful weapon choice and attack-generation design.
  Produce weapon-bearing image references before video actions. Do not ask H3
  to invent a weapon from the unarmed portrait or burn projectile/impact effects
  into the character motion.
- The current recommendation is an original Chinese-inspired single-shot light
  crossbow for her ranged-support role; it is a design proposal, not an accepted
  historical reconstruction or an already approved final weapon. The hammer and
  rope in her portrait remain artisan props. Read
  `docs/CHARACTER_WEAPONS_AND_ACTIONS_20261010.md` for the reasoning and pipeline.

## Latest correction — imagegen for images, portrait first, 2026-10-10

- The user explicitly corrected the tool split: all image-related character
  design, portraits, sprite source images, UI and effect artwork use the built-in
  imagegen tool. Local MiniMax H3 is for video animation only. This supersedes
  the earlier interpretation that H3 should generate still images too.
- The user rejected both local-H3 Atang world-image candidates. Preserve their
  provenance, but do not adopt them or use them as identity/design references.
- Atang starts from her existing story/personality/gameplay role and the
  separately generated portrait. That portrait review is now complete; derive
  subsequent images and motion from the approved image named above.
- Existing role: Old Liang's female apprentice, knows ship equipment, proposes
  cooperation to rescue her mentor, provides cannon and ranged support. Exact
  age, face and costume were not previously finalized. Distinguish new visual
  proposals from established story facts; do not ask the user to restate them.

## Latest authorization — local asset production, 2026-10-10

- The user approved starting the needed asset generation and continuing the
  game work. Keep the current ship for this iteration; different future ship
  types should have their own models. Do not replace or upscale the current
  ship merely because larger-ship proposals exist.
- Generate image artwork with built-in imagegen and video animation with the
  existing local MiniMax H3 setup. Begin with concrete samples and inspect output
  before expanding a character or action set. Save workflows, task IDs, inputs,
  original outputs, processing recipes and review status under Working.
- Earlier analysis-only wording below is historical and superseded for this
  authorized asset production. All v03 art, independent portrait, game UI and
  rejected-batch preservation rules remain binding.
- The user canceled the request to investigate high CPU/headless Chrome/Node.js
  and suspects another digital-human task. Do not investigate or stop unrelated
  processes. Inspect only this task's generation service as needed to operate it.

## Binding game UI, scale and sea requirements — 2026-10-10

- The user explicitly rejects website/CSS/demo-panel thinking for this game's
  UI. Use game art direction: authored graphical HUD frames, portraits, skill
  and status icons, health bars, cursors, ground indicators and state animations.
  Do not use frontend-skill's webpage/app styling to determine the game HUD.
- Before claiming UI design complete, provide full-screen visual art layouts
  for the relevant scenes and graphical interaction/state sheets, then verify
  them in Godot. Text/layout specifications and engineering diagrams are not
  substitutes for the actual game UI artwork. Readable engine-rendered text is
  allowed alongside graphical assets; do not bake all labels into bitmaps.
- Decide human scale, ship class, usable deck area, aisle widths and total
  simultaneous combatants together. Current 16 x 5.3 m runtime ship is a small
  vessel in the proposed game classification, not an approved large warship.
  Crew aboard, units simultaneously fighting and controllable party size are
  separate quantities. The larger ship/capacity values remain design proposals.
- Movement previews and valid/invalid placement cues must derive from the real
  reachable area, use designed game effects, and agree with actual movement.
- Revisit the supplied HD-2D water/weather references. Plan calm water, wind,
  waves, rainfall, wet surfaces, reflections, sails, wakes and projectiles as a
  coherent system. Rainfall and wave height are independent controls. Keep v03
  art direction; do not assume a river example supplies an ocean/storm solution.
- Read `docs/GAME_UI_SHIP_SCALE_AND_SEA_DESIGN_20261010.md` for the latest
  reference findings, measured/proposed scale distinction and visual deliverables.
  This is still design analysis; no new game implementation or generation batch
  was started during this review.

## Latest review and production direction — 2026-10-10

- The user requests analysis of the first demo's incomplete character art,
  text-heavy UI, sea/wake/cannon feedback, battle camera/scale and deck navigation.
  This review turn does not authorize starting a new generation batch or repairs.
- Use the existing local MiniMax H3 environment for character generation and
  other suitable generated media. Do not use online MiniMax/TokenHub video as a
  fallback. Online generation remains the route for needed 3D models within the
  existing budget and task rules. Do not change external model installations.
- Dialogue requires separately authored character portraits, preferably half
  body; do not crop or enlarge in-world sprites as the dialogue art.
- Design one coherent v03-compatible UI across exploration, dialogue, deployment,
  character orders and naval orders. Reduce persistent text and reveal controls
  according to context; retain short labels where they improve comprehension.
- The second enemy's movement stall has been reproduced in the unchanged Godot
  scene. The current rectangle/two-obstacle steering is not real pathfinding;
  do not treat the current battle's balance or all deck routes as validated.
- Read `docs/DEMO_REVIEW_AND_REVISION_ANALYSIS_20261010.md` for the diagnosis,
  local H3 entry, asset scope and proposed correction order. These are proposals
  for the next iteration, not completed fixes or accepted new art.

## Binding art direction — 2026-10-10

- The user explicitly requires every following scene to retain the already
  validated v03 art style. Do not replace it with simplified prototype art.
- Boarding must take place on the actual ship's deck, with its full hull,
  cabin, rails, mast and rigging. The isolated rectangular test platform is
  rejected and must not be presented as the demo's boarding environment.
- Sea water and moving-ship wakes must use the same art language as v03.
  Preserve its water palette, painted detail scale and reflections. Wakes
  must follow real travel history, heading and speed, including turns.

## Latest authorization — first playable demo, 2026-10-10

- The user now asks to make the proposed story/gameplay validation. The prior
  planning-only restriction is superseded for a small playable Godot demo.
- First define the two characters, skills, dialogue and asset requirements,
  then build with retained resources. Preserve the v03 scene and its art baseline
  via a separate demo entry. This is not full-game implementation authorization.
- Naval cannonballs should have real flight and spatial collision: changing
  course after launch can avoid direct damage. No homing/guaranteed hit hidden
  behind projectile graphics. Keep sea encounters and escape on the same map.
- Do not buy a generic skill pack or expand paid generation preemptively.
  Existing cost limits, task tracking and source preservation still apply.

The first playable entry is now `Godot/return_demo.tscn`; launch it with
`tools/godot-demo.ps1 -Mode Play|Check|Capture|Record`. Read
`docs/DEMO_FIRST_PLAYABLE_RESULT_20261010.md` for evidence and limitations.
The real ship's reefed-sail boarding variant and the v03-derived water are
implemented. Distinct character portraits and accepted attack animations are
still missing for the combat cast; do not claim those are finished or that user
art review passed. Two built-in imagegen candidates (OldLiang's standing pose
and a six-effect atlas) are now integrated, with prompts and source images in
their Working folders. Their tool did not report monetary prices. No new
Tencent or MiniMax job was submitted. The planning-only sections below record
earlier phases and are superseded by this execution authorization.

## Latest combat direction — analysis only, 2026-10-10

- The user proposes default automatic real-time attacks and skills for both
  people and ships, with very slow bullet time when selecting a unit to order
  movement, targeting or skills. This replaces the prior turn-based demo
  recommendation as the current direction to analyze, not implementation approval.
- The user explicitly clarified: character battles enter dedicated scenes and
  use story-constrained deployment areas; naval encounters occur directly on
  the sailing sea map. Sailing resumes after the player gets far enough away
  and enemies abandon or cannot maintain pursuit. Do not make naval arenas.
- Read `docs/COMBAT_AUTOMATION_AND_ENCOUNTERS_20261010.md`. Time scale, pursuit
  thresholds, AI policies and revised skills there are proposals to test.
- Continue planning only. No gameplay code, new generation or spending is
  authorized by this analysis request. Preserve the v03 visual baseline.

## Latest request — short demo planning, 2026-10-09

- The user requests a short story and core-play validation plan: character
  control/attributes, companion recruitment, one small naval battle and boarding.
  Keep controls simple and prioritize combat feedback, meaningful growth and
  story involvement. Later randomness is desirable; this demo may be fixed.
- Read `docs/DEMO_STORY_AND_PRODUCTION_PLAN_20261009.md` for the current concrete
  proposal and MiniMax/modeling/Godot production split. Its story, names,
  15–20 minute playtime target and battle rules are proposals, not final approval.
- The requested next step is planning. Do not begin gameplay implementation or
  new paid generation from this document alone. Preserve the v03 art baseline.

## Latest user decisions — 2026-10-09 design discussion

- Harbor v03 now **basically passes the user's art-style validation**. Its
  overall feel is accepted as a working style baseline; detail can improve.
  This is not blanket approval of sailing/naval-combat visuals or every asset.
- The game is confirmed as an RPG with NPC conversations, dialogue boxes,
  staged story scenes and plot progression.
- The user explicitly prefers **roughly balanced character adventure and fleet
  management**. Do not reduce the fleet to a cosmetic travel vehicle, or reduce
  the characters to management stat bonuses.
- The broad combat preference now follows the 2026-10-10 direction above;
  detailed combat rules, growth, story and worldview remain undecided.
  Read `docs/GAME_DESIGN_DISCUSSION_20261009.md` as the earlier discussion; its battle modes,
  story hook, party/fleet sizes and optional modes are proposals, not approvals.
- Current requested work is design discussion. Do not infer authorization for
  full gameplay implementation, a new paid batch, or renewed art polishing.

## Latest execution authorization

The user now explicitly authorized continuing into a real Godot visual sample,
using the latest stable Godot and generating necessary assets. MiniMax and
Tencent TokenHub 3D generation are authorized within available funds/credits.
Check the balance, submit small concrete jobs, record costs and task IDs, and
do not repeat completed/uncertain jobs. No recharge or unbounded batch is implied.
The earlier research-only status below is superseded for this visual trial.
Keep the scope on coherent in-engine art, not a full game/editor or combat system.
Godot 4.7.2 was rechecked as the current stable download and successfully launched
with --headless --version for this authorized execution.

Read `docs/GODOT_REBOOT_PLAN.md` and
`docs/GODOT_HD2D_VISUAL_RESEARCH_20261008.md` before further work.
The 2026-10-09 continuation also recorded `docs/GODOT_REFERENCE_STUDY_20261009.md`
and `docs/GODOT_VISUAL_TRIAL_20261009.md`. Read these for the latest sample,
evidence, license limits and remaining visual work. `tools/godot-harbor.ps1`
is the Play/Check/Stills/Record entry point. No new TokenHub or MiniMax jobs
were submitted during this continuation; two built-in imagegen assets were added.

## Latest visual review — 2026-10-09

The user rejected Harbor v02 as too basic and lacking the intended HD-2D look,
then requested deeper research. Read `docs/GODOT_HD2D_DIRECTION_RESET_20261009.md`
before continuing visual work. Its companion comparison page is
`Artifacts/HD2D-Research-20261009/index.html`.
The new research actually ran the author reference project and controlled
camera/DOF/normal comparisons. These are diagnostic images, not a new accepted
art version. Merely lowering the camera or adding blur did not fix v02.
Rebuild composition and shared art direction first; do not continue decorating
the rejected layout or batch-generate character normals before a pose is proven.
The research did not modify the Godot runtime or submit new generation jobs.

The user subsequently authorized the next visual iteration and topped up Tencent,
explicitly limiting this round to 100 CNY total. See
`Assets/HarborTrial/v03/tencent-budget.json`. Account funds above 100 CNY are not
additional authorization. Use `tools/assets/submit_harbor_model.py` for bounded
Normal-mode HY-3D submissions; reserve estimated cost before submission and keep
uncertain outcomes reserved. Do not recharge or automatically repeat a task.

## Latest delivered iteration — v03, 2026-10-09

Read `docs/GODOT_VISUAL_TRIAL_V03_20261009.md` for the next completed visual
candidate. `Godot/quay.tscn` is now the default scene; use
`tools/godot-quay.ps1 -Mode Play|Check|Stills|Record`. The old harbor scene and
v02 evidence remain available through the old explicit-scene launcher.
The new review includes real 1600x900 GPU images, a 30.17-second 720p/30fps movie,
and an identical-pose far-DOF on/off comparison. The user subsequently accepted
its basic harbor art direction, while reserving detail polish and sea visuals.
One HY-3D-3.1 Normal ship task completed: `1499995051698167808`. Estimated
2.40 CNY is reserved out of the 100 CNY cap; 97.60 CNY remains authorized.
Do not resubmit that model. Four built-in imagegen sources have separate prompt
records; their tool did not report monetary prices. No new MiniMax task was run.
Buildings/quay/ship are 3D; character/tree sprites and a distant shore art layer
are authored for the limited camera. Character per-frame volume normals,
full deck navigation, naval combat and all-angle scenery are not complete.

## Current user direction

- Use Godot. Retire UE, its editor/WFC/terrain work and old material rework.
- The FIRST game starts from Ming China and includes ocean voyages and Europe.
- The user now considers alternate-history Ming without time travel. Time travel
  is optional; do not keep it as a settled protagonist requirement.
- Ship cannon combat and character combat, including boarding, are contemplated.
  The current preference is automatic real-time combat with bullet-time orders,
  dedicated character arenas and continuous sea encounters with disengagement.
- The harbor style has basically passed validation. Current focus is the RPG
  loop, character/fleet balance, combat choices and story/world design. Sailing
  and naval-combat art need their own targeted validation later.
- Godot 4.7.2 is downloaded under `Local/Godot/4.7.2/`; official SHA-512 matches.
  After the later execution authorization it ran successfully with Forward+ on
  RTX 4090. `Godot/` now contains the limited harbor sample.
- Do not expand the authorized visual trial into a full game, buy plugins or
  submit unbounded asset batches merely because a plan exists. The current
  v02 harbor/camera/art was rejected; v03 is now the basically accepted harbor
  style baseline, not approval of every asset or every future viewing scale.

## Retained MiniMax workflow

- The user narrowed old-project retention to MiniMax character/sprite production,
  especially eight directions. New authorized harbor trial candidates are kept
  separately in `Assets/HarborTrial/`; they are not accepted final art.
- Read `docs/CHARACTER_PRODUCTION.md`. Preserve accepted frames, original videos,
  input images, source recipes and task/cost records. Old receipts are history,
  not new authorization.
- Only movement requires eight directions. The next basic attack needs a RIGHT
  source and mirrored LEFT presentation, not eight generated attack directions.
- Determine attack side relative to the camera, stabilize facing during the
  action, and keep gameplay targeting/impact separate from animation.
- Existing mirroring reverses handedness. Preserve ground pivots and useful body
  motion; do not align every frame by its visible bounding box. Input movement
  must not wait for a video clip to finish.
- ShenYan's appearance, old canvas sizes and source cut points are candidates or
  examples, not the new protagonist, new art standard or generic recipe.
- Rejected attacks remain rejected. Do not restore or resubmit the closed batch.
- The remote adapter preserves an old TokenHub route. Recheck current provider,
  model, settings and costs for an actual new job; no automatic paid retries.
- Eight Python tools remain for MiniMax sprites. Offline validation proves only
  portable data consistency. Current Godot integration has separate input/route/
  geometry checks and GPU images/video; none proves user art acceptance.
- Historical recipes can retain obsolete engine-unit fields for provenance;
  do not use them as Godot world units. Current runtime manifests retire these.
- New candidates belong in Working. Do not repackage accepted Library images
  just to review or reorganize the workflow.

## Visual evaluation

- Review actual Godot images and normal-speed footage at gameplay scale.
  Compilation, pixel differences, RGB matches or asset counts are not art scores.
- Preserve clear forms, readable space, coherent texture detail and organized
  light. No noise/geometry-density substitute for a shared art style.
- A future small scene should show people, architecture, vegetation, shore,
  water and a ship together. Strong blur/glow must not conceal weak base art.
- FrameRonin screenshots and advertised capabilities are vendor references,
  not our runtime results. No paid plugin was purchased or tested.
- Existing MiniMax hand-painted people differ from the more explicit pixel art
  in the public FrameRonin scenes. Resolve this visually; do not blindly combine.
- Runtime root is `Godot/`, not the repository root. Do not import
  raw task records, Local downloads or the entire source library.

## History and boundaries

- Follow `docs/HISTORICAL_SOURCE_POLICY.md`. Historical claims, including about
  Europe, require Chinese official or reputable domestic scholarly/publishing
  sources. Overseas images need provenance; their captions are not authority.
- Original alternate history is permitted and must be distinct from real facts.
  Actual disputed historical/territorial claims require evidence and explicit
  resolution. Preserve the rules for accurate Xinjiang/Xizang representations,
  modern official China maps, period/source labels and no generated borders.
- User original references, required original P1 evidence, old review records,
  and legacy source/license/cost records are outside this working repository:
  `D:/Work/project/joker/chess-legacy-evidence-20261008`.
  Do not routinely search them or treat old instructions as active.
- Other legacy environment assets/tools were deleted. Read `docs/CLEANUP_20261008.md`.
- Credentials, external engines/models and unrelated personal files are untouched.
  Do not broadly reset/clean Git or discard pre-existing staged work.
- No proactive cross-chat messages; use file handoff unless the user authorizes
  messaging another chat.
