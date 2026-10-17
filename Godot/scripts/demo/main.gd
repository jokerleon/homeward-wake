extends Node3D
const Port=preload("res://scripts/demo/port.gd")
const Pawn=preload("res://scripts/demo/pawn.gd")
const Sea=preload("res://scripts/demo/sea.gd")
const Boarding=preload("res://scripts/demo/boarding.gd")
const Effects=preload("res://scripts/demo/fx.gd")
const UIArt=preload("res://scripts/demo/ui_art.gd")
const DeckFeedback=preload("res://scripts/demo/deck_feedback.gd")
const SAVE="user://return-home-demo-v1.json"
var port
var sea
var boarding
var fx
var companion
var camera
var mode="port"
var recruited=false
var fit=""
var growth_trait=""
var completed=false
var selected=""
var aim_mode="move"
var paused=false
var lost=false
var stopped_story=false
var dialogue=[]
var dialogue_index=0
var dialogue_done=Callable()
var dialog_open=false
var choosing=false
var toast_time=0.0
var previous_sea_state="sailing"
var last_escaped=0
var gui
var title_label
var objective
var hint
var toast_label
var speed_label
var parties=[]
var dialog_panel
var dialog_name
var dialog_body
var portrait
var dialog_actions
var command_panel
var command_title
var command_details
var command_actions
var main_action
var font
var review=false
var manual_review=false
var review_dir=""
var review_time=0.0
var review_step=0
var mode_time=0.0
var captures=[]
var review_scene="story"
var review_dialogue_time=0.0
var checkpoint={}
var old_liang: Node3D
var old_liang_face: MeshInstance3D
var old_liang_portrait: AtlasTexture
var deck_overview=false
var ui_art
var party_faces=[]
var party_names=[]
var party_bars=[]
var party_status=[]
var party_cooldowns=[]
var menu_button
var overview_button
var pause_panel
var pause_shade
var command_skill
var command_auto
var speed_frame
var compass_face
var journal=[]
var journal_panel
var deck_feedback
var pause_title
var pause_resume
var dialog_portrait_space
var companion_following=false
var companion_follow_speed=0.0
var follow_leader_previous=Vector3.ZERO
var follow_has_previous=false

func _ready() -> void:
	get_window().title="归港的人 · HD-2D 故事玩法验证"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-review-dir="):review=true;review_dir=arg.trim_prefix("--demo-review-dir=")
		if arg.begins_with("--demo-manual-review-dir="):review=true;manual_review=true;review_dir=arg.trim_prefix("--demo-manual-review-dir=")
		if arg.begins_with("--demo-scene="):review_scene=arg.trim_prefix("--demo-scene=")
	if review:DirAccess.make_dir_recursive_absolute(review_dir)
	if manual_review:get_window().title="归港的人 · 调整版实机验证"
	port=Port.new()
	add_child(port)
	port.set_process(false)
	camera=port.camera
	# Keep exactly one camera, sun and environment while showing different local scenes.
	camera.reparent(self)
	# The reflection viewport must keep rendering when the port subtree is hidden.
	port.reflection_view.reparent(self)
	port.sun.reparent(self)
	for child in port.get_children():
		if child is WorldEnvironment:child.reparent(self)
	fx=Effects.new()
	add_child(fx)
	companion=Pawn.new()
	port.add_child(companion)
	companion.setup("atang","阿棠",0,port.retained_sprite_frames,Color.WHITE,"explore")
	companion.position=Vector3(-0.2,1.815,6.2)
	sea=Sea.new()
	add_child(sea)
	sea.setup(port,fx)
	sea.visible=false
	boarding=Boarding.new()
	add_child(boarding)
	boarding.setup(port,fx,camera)
	deck_feedback=DeckFeedback.new();boarding.add_child(deck_feedback);deck_feedback.setup(boarding)
	boarding.visible=false
	_build_ui()
	_make_old_liang()
	if FileAccess.file_exists(SAVE) and not review:
		var saved=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if saved is Dictionary and saved.get("version",0)==1:checkpoint=saved
	if review_scene=="sea":
		recruited=true;fit="mount";depart()
	elif review_scene=="deck":
		recruited=true;fit="mount";growth_trait="pursuit";sea.reset(fit);enter_boarding()
	else:
		show_dialogue([["船主","老梁说，今早就能交船。可约定的时辰早过了。"],["旁白","码头边的学徒望着湾口，手里攥着一张折旧的修船单。"]],Callable())
	_refresh_main_action()
	print("RETURN_DEMO_READY: separate entry; retained v03 resources; temporary character presentation")

func _make_old_liang() -> void:
	if not preload("res://scripts/demo/character_motion.gd").bundle("old-liang","explore").is_empty():
		var rescued=Pawn.new()
		rescued.name="RescuedShipwright"
		add_child(rescued)
		rescued.setup("old-liang","老梁",0,port.retained_sprite_frames,Color.WHITE,"explore")
		rescued.health_root.visible=false;rescued.marker.visible=false
		old_liang=rescued;old_liang_face=rescued.surface
		old_liang.visible=false
		return
	var texture=load("res://assets/demo/old-liang.png") as Texture2D
	var pixel_size=1.78/722.0
	old_liang=Node3D.new()
	old_liang.name="RescuedShipwright"
	add_child(old_liang)
	old_liang_face=MeshInstance3D.new()
	var quad=QuadMesh.new()
	quad.size=Vector2(1254,1254)*pixel_size
	old_liang_face.mesh=quad
	var paint=ShaderMaterial.new()
	paint.shader=load("res://shaders/quay_actor.gdshader")
	paint.set_shader_parameter("color_atlas",texture)
	paint.set_shader_parameter("atlas_region",Vector4(0,0,1,1))
	paint.set_shader_parameter("tint",Color("f3ecdb"))
	old_liang_face.material_override=paint
	old_liang_face.position=Vector3(2,369,0)*pixel_size
	old_liang_face.layers=5
	old_liang_face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	old_liang.add_child(old_liang_face)
	var shadow=MeshInstance3D.new()
	shadow.mesh=port.hero_shadow.mesh
	shadow.material_override=port.hero_shadow.material_override
	shadow.position.y=0.015
	old_liang.add_child(shadow)
	var label=Label3D.new()
	label.font=font
	label.text="老梁"
	label.font_size=40
	label.pixel_size=0.009
	label.position.y=2.05
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size=8
	old_liang.add_child(label)
	old_liang.visible=false

func _build_ui() -> void:
	ui_art=UIArt.new()
	font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	var canvas=CanvasLayer.new();add_child(canvas)
	gui=Control.new();gui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme=Theme.new();theme.default_font=font;theme.default_font_size=19;gui.theme=theme
	canvas.add_child(gui)
	var quest=_panel(Vector2(24,24),Vector2(480,106));quest.name="QuestFrame"
	quest.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var quest_content=_stack(quest)
	title_label=_text(quest_content,"归港的人",16,Color("d9c48f"))
	objective=_text(quest_content,"",20);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speed_frame=_panel(Vector2.ZERO,Vector2(220,60),"normal");speed_frame.name="TimeStateFrame"
	_dock(speed_frame,Vector2(0.5,0),Vector2(-110,24),Vector2(220,60))
	speed_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speed_label=_text(speed_frame,"",21,Color("e7ca87"));speed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label=_label(gui,"",Vector2.ZERO,Vector2(900,70),20)
	_dock(toast_label,Vector2(0.5,0),Vector2(-450,138),Vector2(900,70))
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint=_label(gui,"",Vector2.ZERO,Vector2(850,28),16,Color("d9d2bd"))
	_dock(hint,Vector2(0.5,1),Vector2(-425,-36),Vector2(850,28));hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in range(2):
		var card=Control.new();card.mouse_filter=Control.MOUSE_FILTER_IGNORE;gui.add_child(card)
		card.name="PartyCard"+str(i)
		_dock(card,Vector2(0,1),Vector2(28+i*136,-232),Vector2(116,216))
		var button=_button(card,"",Callable(self,"_party_selected").bind(i));button.name="PortraitButton"
		button.custom_minimum_size=Vector2(116,144);button.size=Vector2(116,144)
		for state in ["normal","pressed","disabled"]:button.add_theme_stylebox_override(state,ui_art.style("portrait"))
		button.add_theme_stylebox_override("hover",ui_art.style("portrait_selected"))
		var interior=VBoxContainer.new();interior.name="Content";interior.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(interior);interior.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		interior.offset_left=14;interior.offset_top=14;interior.offset_right=-14;interior.offset_bottom=-14
		interior.add_theme_constant_override("separation",4)
		var face=ui_art.picture(interior,ui_art.head("船主" if i==0 else "阿棠"),Vector2.ZERO,Vector2(88,88))
		face.custom_minimum_size=Vector2(0,88)
		var label=_text(interior,"船主" if i==0 else "阿棠",18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var bar=ui_art.health(card,Vector2(0,150),Vector2(116,18))
		var cooldown=ui_art.health(card,Vector2(0,173),Vector2(116,14));cooldown.fill.texture=ui_art.region("gold")
		var status=_label(card,"",Vector2(0,193),Vector2(116,22),15);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		parties.append(button);party_faces.append(face);party_names.append(label);party_bars.append(bar);party_status.append(status);party_cooldowns.append(cooldown)
	main_action=_button(gui,"",Callable(self,"_main_action"))
	_dock(main_action,Vector2.ONE,Vector2(-316,-88),Vector2(288,60))
	menu_button=_button(gui,"",Callable(self,"toggle_pause"));menu_button.icon=ui_art.button_icon("pause")
	ui_art.decorate_icon_button(menu_button)
	menu_button.custom_minimum_size=Vector2(64,56)
	_dock(menu_button,Vector2(1,0),Vector2(-92,24),Vector2(64,56));menu_button.tooltip_text="暂停 · 空格"
	overview_button=_button(gui,"总览",func():deck_overview=not deck_overview)
	_dock(overview_button,Vector2(1,0),Vector2(-240,24),Vector2(132,56))
	compass_face=ui_art.picture(gui,ui_art.region("compass"),Vector2.ZERO,Vector2(114,114))
	_dock(compass_face,Vector2(1,0),Vector2(-144,106),Vector2(114,114))
	dialog_panel=_panel(Vector2.ZERO,Vector2(1544,252),"paper");dialog_panel.name="DialogueFrame"
	_dock(dialog_panel,Vector2(0,1),Vector2(28,-280),Vector2(1544,252))
	dialog_panel.anchor_right=1;dialog_panel.offset_right=-28
	var dialogue_row=_stack(dialog_panel,false);dialogue_row.add_theme_constant_override("separation",20)
	dialog_portrait_space=Control.new();dialog_portrait_space.custom_minimum_size.x=280;dialogue_row.add_child(dialog_portrait_space)
	var dialogue_text=_stack(dialogue_row);dialogue_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	dialog_name=_text(dialogue_text,"",23,Color("79532f"));dialog_name.custom_minimum_size.y=30
	dialog_body=_text(dialogue_text,"",23,Color("263431"));dialog_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog_body.custom_minimum_size.y=76;dialog_body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	for label in [dialog_name,dialog_body]:label.add_theme_constant_override("shadow_offset_y",0)
	dialog_actions=_stack(dialogue_text,false);dialog_actions.add_theme_constant_override("separation",12)
	portrait=ui_art.picture(gui,null,Vector2.ZERO,Vector2(316,470))
	_dock(portrait,Vector2(0,1),Vector2(40,-498),Vector2(316,470))
	command_panel=_panel(Vector2.ZERO,Vector2(776,198));command_panel.name="CommandFrame"
	_dock(command_panel,Vector2.ONE,Vector2(-804,-230),Vector2(776,198))
	var command_content=_stack(command_panel)
	command_title=_text(command_content,"",21,Color("e2c58b"));command_title.custom_minimum_size.y=28
	command_details=_text(command_content,"",16);command_details.custom_minimum_size.y=28
	command_actions=_stack(command_content,false);command_actions.add_theme_constant_override("separation",8)
	command_panel.visible=false
	pause_shade=ColorRect.new();pause_shade.color=Color(0.03,0.06,0.07,0.58)
	gui.add_child(pause_shade);pause_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel=_panel(Vector2.ZERO,Vector2(500,404));pause_panel.name="PauseFrame"
	_dock(pause_panel,Vector2(0.5,0.5),Vector2(-250,-202),Vector2(500,404))
	var pause_content=_stack(pause_panel);pause_content.add_theme_constant_override("separation",12)
	pause_title=_text(pause_content,"航程暂停",28,Color("e2c58b"));pause_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	pause_resume=_button(pause_content,"继续",Callable(self,"toggle_pause"))
	_button(pause_content,"重试本段",Callable(self,"retry_checkpoint"))
	_button(pause_content,"对白回看",Callable(self,"show_journal"))
	var help=_text(pause_content,"WASD 行走 · E 交谈\n点击人物下令 · 右键结束指挥\n空格暂停 · Tab 甲板总览",17);help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	pause_panel.visible=false;pause_shade.visible=false
	journal_panel=_panel(Vector2.ZERO,Vector2(980,540));journal_panel.name="JournalFrame"
	_dock(journal_panel,Vector2(0.5,0.5),Vector2(-490,-270),Vector2(980,540));journal_panel.visible=false

func _dock(control: Control,corner: Vector2,at: Vector2,extent: Vector2) -> void:
	control.anchor_left=corner.x;control.anchor_right=corner.x;control.anchor_top=corner.y;control.anchor_bottom=corner.y
	control.offset_left=at.x;control.offset_top=at.y;control.offset_right=at.x+extent.x;control.offset_bottom=at.y+extent.y

func _stack(parent: Node,vertical: bool=true) -> BoxContainer:
	var box=VBoxContainer.new() if vertical else HBoxContainer.new()
	box.name="Content";box.add_theme_constant_override("separation",8)
	parent.add_child(box)
	return box

func _text(parent: Node,value: String,font_size: int,color: Color=Color("efe8d5")) -> Label:
	var label=_label(parent,value,Vector2.ZERO,Vector2.ZERO,font_size,color)
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return label

func _label(parent,text_value: String,at: Vector2,extent: Vector2,size: int,color: Color=Color("efe8d5")) -> Label:
	var label=Label.new()
	label.text=text_value;label.position=at;label.size=extent
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.03,0.07,0.07,0.85))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel(at: Vector2,extent: Vector2,skin: String="panel") -> PanelContainer:
	var panel=PanelContainer.new();panel.position=at;panel.size=extent
	panel.add_theme_stylebox_override("panel",ui_art.style(skin))
	gui.add_child(panel)
	return panel

func _button(parent,text_value: String,callback: Callable) -> Button:
	var button=Button.new();button.text=text_value
	button.custom_minimum_size=Vector2(120,56)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var kind=""
	for term in {"继续":"play","确认":"confirm","开战":"blade","出航":"ship","交谈":"confirm","取消":"back","返回":"back","重试":"back","迎战":"cannon","弹药":"ball","换弹":"ball","齐射":"salvo","撤离":"rudder","强攻":"blade","压制":"crossbow","加固":"hull","改良":"mount","守望":"shield","乘隙":"blade"}:
		if text_value.contains(term):kind={"继续":"play","确认":"confirm","开战":"blade","出航":"ship","交谈":"confirm","取消":"back","返回":"back","重试":"back","迎战":"cannon","弹药":"ball","换弹":"ball","齐射":"salvo","撤离":"rudder","强攻":"blade","压制":"crossbow","加固":"hull","改良":"mount","守望":"shield","乘隙":"blade"}[term];break
	ui_art.decorate_button(button,kind)
	if callback.is_valid():button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _set_dialogue_portrait(speaker: String) -> void:
	if speaker=="老梁" and old_liang is Pawn:old_liang.perform("gesture")
	portrait.texture=ui_art.portrait(speaker);portrait.modulate=Color.WHITE
	portrait.visible=portrait.texture!=null
	dialog_portrait_space.visible=portrait.visible

func show_journal() -> void:
	_clear(journal_panel)
	var content=_stack(journal_panel)
	_text(content,"航程对白",25,Color("e2c58b"))
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=350;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
	var lines=VBoxContainer.new();lines.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(lines)
	for entry in journal:
		var label=Label.new();label.text=entry;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x=880;label.add_theme_font_size_override("font_size",20);lines.add_child(label)
	var back=_button(content,"返回",func():journal_panel.visible=false);back.size_flags_horizontal=Control.SIZE_SHRINK_END
	journal_panel.visible=true

func _clear(container) -> void:
	for child in container.get_children():container.remove_child(child);child.queue_free()

func show_dialogue(lines: Array,callback: Callable) -> void:
	selected=""
	command_panel.visible=false
	dialogue=lines
	dialogue_index=0
	review_dialogue_time=0.0
	dialogue_done=callback
	dialog_open=true
	choosing=false
	dialog_panel.visible=true
	_update_dialogue()
	_apply_time()

func _update_dialogue() -> void:
	dialog_name.text=dialogue[dialogue_index][0]
	dialog_body.text=dialogue[dialogue_index][1]
	_set_dialogue_portrait(dialog_name.text)
	var line=dialog_name.text+"："+dialog_body.text
	if journal.is_empty() or journal.back()!=line:journal.append(line)
	_clear(dialog_actions)
	_button(dialog_actions,"继续  E",Callable(self,"advance_dialogue"))
	_button(dialog_actions,"跳过本段",Callable(self,"skip_dialogue"))

func advance_dialogue() -> void:
	if not dialog_open or choosing:return
	dialogue_index+=1
	if dialogue_index<dialogue.size():_update_dialogue();return
	_finish_dialogue()

func skip_dialogue() -> void:
	if not dialog_open or choosing:return
	_finish_dialogue()

func _finish_dialogue() -> void:
	var callback=dialogue_done
	dialogue_done=Callable()
	dialog_open=false
	dialog_panel.visible=false
	if callback.is_valid():callback.call()
	_apply_time()
	_refresh_main_action()

func choice(speaker: String,text_value: String,options: Array) -> void:
	review_dialogue_time=0.0
	dialog_open=true;choosing=true
	dialog_panel.visible=true
	dialog_name.text=speaker
	dialog_body.text=text_value
	_set_dialogue_portrait(speaker)
	_clear(dialog_actions)
	for option in options:_button(dialog_actions,option[0],option[1])
	_apply_time()

func _close_choice() -> void:
	dialog_open=false;choosing=false
	dialog_panel.visible=false
	_apply_time()

func talk() -> void:
	if recruited:return
	show_dialogue([["阿棠","老梁被那伙人扣在船上了。他们的桅架坏了，要他修好才肯放人。"],["船主","他替我保住过这艘船。现在，轮到我去接他回来。"],["阿棠","他们走不远。你肯开船，我就上炮位。"]],Callable(self,"recruit_choice"))

func recruit_choice() -> void:
	choice("船主","一起出海，把老梁平安带回来。",[["同行，准备出航",Callable(self,"recruit")],["稍后再谈",Callable(self,"_close_choice")]])

func recruit() -> void:
	if recruited:return
	recruited=true
	fx.play("success")
	choice("阿棠","还有一点材料，出航前可以改一处。",[["加固船体 · 船况 +40",Callable(self,"choose_fit").bind("hull")],["改良炮架 · 装填更快",Callable(self,"choose_fit").bind("mount")]])

func choose_fit(value: String) -> void:
	fit=value
	_close_choice()
	_save_checkpoint("port")
	_refresh_main_action()
	toast("阿棠已入队。前往码头，准备出航。")

func depart() -> void:
	if not recruited or fit.is_empty():return
	dialog_open=false;choosing=false;dialog_panel.visible=false
	sea.reset(fit)
	sea.special_pending=true
	stopped_story=false
	growth_trait=""
	_switch_mode("sea")
	_save_checkpoint("sea")
	toast("阿棠：湾口那艘船，就是他们。点击敌船可下令迎战。")

func _switch_mode(next: String) -> void:
	if next!="sea":sea.weather_visual.restore_lighting()
	mode=next;mode_time=0
	toast_time=0;toast_label.visible=false
	selected="";paused=false;lost=false
	port.visible=mode=="port"
	sea.visible=mode=="sea"
	boarding.visible=mode=="deck"
	old_liang.visible=completed
	port.controls_enabled=mode=="port"
	port.reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	command_panel.visible=false
	fx.clear()
	if mode=="port":port._set_camera(2)
	elif mode=="deck":
		deck_overview=false
		_update_deck_camera(1.0)
		camera.attributes.dof_blur_far_enabled=false
	else:
		camera.fov=40
		camera.attributes.dof_blur_far_enabled=false
		_update_sea_camera(1.0)
	_apply_time()
	_refresh_main_action()

func growth_choice() -> void:
	choice("阿棠","刚才那一轮配合不错。上船后，我们这样打——",[["乘隙 · 追击破势目标",Callable(self,"choose_trait").bind("pursuit")],["守望 · 保护附近同伴",Callable(self,"choose_trait").bind("guard")]])

func choose_trait(value: String) -> void:
	growth_trait=value
	_close_choice()
	sea.close_to_board()
	_save_checkpoint("sea")
	_refresh_main_action()
	toast("成长已获得。靠近敌船后，进入甲板布阵。")

func enter_boarding() -> void:
	if growth_trait.is_empty():growth_choice();return
	boarding.reset(growth_trait,sea.suppressed)
	_switch_mode("deck")
	_save_checkpoint("deck")
	toast("在金色区域内部署两人。点击人物，再点击地面调整。")

func begin_boarding() -> void:
	boarding.begin()
	selected=""
	command_panel.visible=false
	_apply_time()
	_refresh_main_action()

func battle_won() -> void:
	if completed:return
	completed=true
	old_liang.position=boarding.navigation.nearest(Vector3(1.35,1.7,3.65),1.0)
	old_liang.position.y=boarding.deck_height(old_liang.position)+0.015
	old_liang.visible=true
	fx.play("success")
	show_dialogue([["随从","别打了！人就在舱里，我们放人！"],["老梁","阿棠？不是叫你留在港里吗……"],["阿棠","先回家。账，回去再算。"]],Callable(self,"return_port"))

func return_port() -> void:
	_switch_mode("port")
	port._set_time_of_day(true)
	port.actor.position=Vector3(4.0,1.855,5.5)
	companion.position=Vector3(5.5,1.855,5.5)
	old_liang.position=Vector3(6.6,1.855,5.55)
	show_dialogue([["老梁","船还能走。你们答应的事，也做到了。"],["阿棠","下次出海，给我留个位置。炮位也行。"],["船主","这张修船单上的货印……怎么会是那支失联船队的？"],["旁白","人已归港。更远的航路，才刚刚露出一角。"]],Callable(self,"finish_story"))

func finish_story() -> void:
	_save_checkpoint("complete")
	_refresh_main_action()
	toast("救援完成 · 阿棠同行 · 船队货印已记录",8)

func _party_selected(index: int) -> void:
	if dialog_open or lost:return
	if mode=="sea":select_ship()
	elif mode=="deck":select_pawn("hero" if index==0 else "atang")
	else:toast("船主：近战与保护　　阿棠：远程压制与炮位支援")

func select_ship() -> void:
	selected="ship";aim_mode="move";command_panel.visible=true
	command_title.text="归舟 · 舷炮指挥"
	_clear(command_actions)
	_button(command_actions,"迎战",func():sea.engage();cancel_command())
	_button(command_actions,"换弹",func():sea.switch_ammo();cancel_command();toast("下一轮弹药已切换"))
	_button(command_actions,"齐射",func():sea.special_pending=not sea.special_pending;cancel_command())
	_button(command_actions,"撤离",func():sea.retreat();cancel_command())
	_button(command_actions,"取消",Callable(self,"cancel_command"))
	_apply_time();fx.play("select")

func select_pawn(key: String) -> void:
	var pawn=boarding.unit(key)
	if pawn==null or pawn.hp<=0:return
	selected=key;aim_mode="move";command_panel.visible=true
	command_title.text=pawn.title+" · "+("指挥" if boarding.active else "部署")
	_clear(command_actions)
	command_skill=null;command_auto=null
	if boarding.active:
		command_skill=_button(command_actions,"强攻" if key=="hero" else "压制",Callable(self,"cast_selected"))
		command_skill.tooltip_text="近战强击" if key=="hero" else "压制射击：命中破势，可打断蓄力；需要装填完成"
		command_auto=_button(command_actions,"自动",func():pawn.auto_skill=not pawn.auto_skill)
	else:
		_button(command_actions,"重置布阵",func():boarding.reset(growth_trait,sea.suppressed);cancel_command())
	_button(command_actions,"取消",Callable(self,"cancel_command"))
	_apply_time();fx.play("select")

func cast_selected() -> void:
	if boarding.skill_order(selected):cancel_command()
	else:toast("技能尚未就绪，或目标不在范围内。")

func cancel_command() -> void:
	selected=""
	command_panel.visible=false
	_apply_time()

func toggle_pause() -> void:
	if dialog_open or lost:return
	paused=not paused
	_apply_time()

func _apply_time() -> void:
	Engine.time_scale=0.001 if paused or dialog_open or lost or (mode=="deck" and not boarding.active) else (0.08 if not selected.is_empty() else 1.0)
	port.controls_enabled=mode=="port" and not paused and not dialog_open

func toast(text_value: String,duration: float=3.5) -> void:
	toast_label.text=text_value;toast_time=duration

func _refresh_main_action() -> void:
	main_action.visible=not dialog_open
	if lost:main_action.text="重试本段";return
	if mode=="deck" and boarding.active:main_action.visible=false;return
	if mode=="port":main_action.text="重走这段航程" if completed else ("出航" if not fit.is_empty() else "与阿棠交谈")
	elif mode=="deck":main_action.text="确认布阵 · 开战" if not boarding.active and boarding.result.is_empty() else "重试甲板战"
	else:main_action.text=("登船" if sea.can_board() else "靠近登船") if sea.ships[1].disabled else "下令迎战"

func _main_action() -> void:
	if dialog_open:return
	if lost:retry_checkpoint();return
	if mode=="port":
		if completed:
			checkpoint={}
			var file=FileAccess.open(SAVE,FileAccess.WRITE);file.store_string("{}")
			get_tree().reload_current_scene()
		elif not fit.is_empty():depart()
		else:talk()
	elif mode=="deck":
		if not boarding.active and boarding.result.is_empty():begin_boarding()
		else:retry_checkpoint()
	else:
		if sea.can_board():enter_boarding()
		elif sea.ships[1].disabled:sea.close_to_board()
		else:sea.engage();cancel_command()

func _process(delta: float) -> void:
	var real_dt=delta/max(Engine.time_scale,0.0001)
	if review and not manual_review:real_dt=1.0/30.0
	mode_time+=real_dt
	toast_time=max(0,toast_time-real_dt)
	toast_label.visible=toast_time>0
	if mode=="port":
		port._process(delta)
		_update_companion_follow(delta)
		companion.visual(camera,delta)
		companion.caption.text="阿棠"+(" · E 交谈" if not recruited else "")
		companion.health_root.visible=false
	elif mode=="sea":_update_sea_camera(real_dt)
	else:
		_update_deck_camera(real_dt)
		boarding.update_visual(delta,selected,0.0 if paused else real_dt)
		if not boarding.result.is_empty() and not paused and (dialog_open or lost):fx.tick(real_dt)
		if not selected.is_empty() and not dialog_open and not paused and not lost and get_viewport().gui_get_hovered_control()==null:
			var mouse=get_viewport().get_mouse_position()
			var point=deck_mouse_point(mouse)
			if point==null:point=screen_to_ground(mouse,1.65)
			deck_feedback.update(selected,point,real_dt)
		else:deck_feedback.clear()
	if old_liang.visible:
		if old_liang is Pawn:
			old_liang.visual(camera,real_dt)
			if not old_liang.performance.is_empty():old_liang.sprite.speed_scale=1.0/maxf(Engine.time_scale,0.001)
			old_liang.health_root.visible=false;old_liang.marker.visible=false
		else:old_liang_face.rotation.y=atan2(camera.global_basis.z.x,camera.global_basis.z.z)
	if mode!="port":port._sync_reflection()
	_update_ui()
	if review and not manual_review:_review_tick(real_dt)

func _update_companion_follow(dt: float) -> void:
	companion.velocity=Vector3.ZERO
	var leader=port.actor.position
	var leader_speed=0.0
	if follow_has_previous and dt>0:
		leader_speed=Vector2(leader.x-follow_leader_previous.x,leader.z-follow_leader_previous.z).length()/dt
	follow_leader_previous=leader;follow_has_previous=true
	if not recruited or completed or dialog_open or paused or dt<=0:
		companion_following=false;companion_follow_speed=0;return
	var offset=leader-companion.position;offset.y=0
	var distance=offset.length()
	if not companion_following and distance>2.0:companion_following=true
	if companion_following and distance<=1.4 and leader_speed<0.1:companion_following=false
	if not companion_following:companion_follow_speed=0;return
	# Match leader speed near the desired gap rather than alternating between
	# a faster catch-up speed and zero at one hard distance threshold.
	var desired=clampf(leader_speed+(distance-1.65)*3.0,0.65,2.8)
	companion_follow_speed=move_toward(companion_follow_speed,desired,dt*8.0)
	var step=minf(companion_follow_speed*dt,maxf(0,distance-1.35))
	var next=companion.position+offset.normalized()*step
	var height=port.walk_height(next.x,next.z)+0.015
	var blocked=height<0.45 or absf(height-companion.position.y)>0.25
	for rect in port.building_blocks:
		if rect.grow(0.15).has_point(Vector2(next.x,next.z)):blocked=true
	if blocked:companion_follow_speed=0;return
	next.y=height
	companion.velocity=(next-companion.position)/dt
	companion.position=next

func _physics_process(delta: float) -> void:
	if dialog_open or paused or lost:return
	fx.tick(delta)
	if mode=="sea":
		sea.tick(delta)
		if sea.ships[0].hp<=0:_failure("归舟已失去航行能力。可从本段检查点重试。")
		elif sea.ships[1].disabled and sea.shots.is_empty() and not stopped_story:
			stopped_story=true
			show_dialogue([["阿棠","他们停了！靠过去，老梁还在船上。"],["船主","先稳住。上船以后，我们互相照应。"]],Callable(self,"growth_choice"))
		if sea.escaped>last_escaped:
			last_escaped=sea.escaped
			_save_checkpoint("sea")
			toast("已摆脱追击。船况与消耗保留，救人目标仍未完成。",5)
	elif mode=="deck" and boarding.active:
		boarding.tick(delta,selected)
		if boarding.result=="won":battle_won()
		elif boarding.result=="lost":_failure("队伍已无法继续作战。可保留成长选择，重试甲板战。")

func _update_sea_camera(dt: float) -> void:
	var point=sea.ships[0].node.position
	var other=sea.ships[1].node.position
	var distance=point.distance_to(other)
	if distance<65 and sea.state!="sailing":point=point.lerp(other,0.42)
	var height=clamp(distance*0.30,16,24)
	var desired=point+Vector3(28,31+height,44+height)
	camera.position=camera.position.lerp(desired,min(dt*3.0,1.0))
	camera.look_at(point+Vector3(0,2,0))

func _update_deck_camera(dt: float) -> void:
	var target=Vector3(-1.4,3.0,0) if deck_overview else Vector3(0,2.4,0)
	var offset=Vector3(24.4,16,10) if deck_overview else Vector3(18,13.5,8.8)
	if not selected.is_empty() and not deck_overview:
		var pawn=boarding.unit(selected)
		if pawn!=null:target=target.lerp(pawn.position+Vector3(0,0.7,0),0.22)
	camera.position=camera.position.lerp(target+offset,minf(dt*5.0,1.0))
	camera.fov=lerpf(camera.fov,34.0 if deck_overview else 32.0,minf(dt*5.0,1.0))
	camera.look_at(target)

func _update_ui() -> void:
	_refresh_main_action()
	main_action.icon=ui_art.button_icon("blade" if mode=="deck" else ("cannon" if mode=="sea" else ("ship" if not fit.is_empty() else "confirm")))
	var real_dt=minf(get_process_delta_time()/maxf(Engine.time_scale,0.0001),0.1)
	dialog_panel.visible=dialog_open
	portrait.visible=dialog_open and portrait.texture!=null
	pause_panel.visible=paused or lost;pause_shade.visible=paused or lost
	if not paused and not lost:journal_panel.visible=false
	pause_title.text="航程受阻" if lost else "航程暂停"
	pause_resume.disabled=lost
	menu_button.visible=not dialog_open and not lost
	menu_button.icon=ui_art.button_icon("play" if paused else "pause")
	overview_button.visible=mode=="deck" and not dialog_open and not paused and not lost
	overview_button.text="近景" if deck_overview else "总览"
	compass_face.visible=mode=="sea" and not dialog_open and not paused
	if mode=="sea":compass_face.rotation=-sea.ships[0].yaw;compass_face.pivot_offset=compass_face.size*0.5
	speed_label.text="布阵" if mode=="deck" and not boarding.active and boarding.result.is_empty() else ("指挥" if not selected.is_empty() else "")
	speed_frame.visible=not speed_label.text.is_empty() and not dialog_open and not paused and not lost
	command_panel.visible=not selected.is_empty() and not dialog_open and not paused and not lost
	main_action.visible=not dialog_open and not command_panel.visible and not paused and not lost and not (mode=="deck" and boarding.active)
	for i in range(2):
		var visible_party=(i==0 or recruited) and not dialog_open and not paused and not lost
		parties[i].visible=visible_party;party_status[i].visible=visible_party and (mode!="deck" or boarding.active)
		for part in ["frame","fill","trail"]:party_bars[i][part].visible=visible_party
		for part in ["frame","fill","trail"]:party_cooldowns[i][part].visible=visible_party and (mode=="sea" or (mode=="deck" and boarding.active))
		parties[i].text=""
		party_faces[i].modulate=Color.WHITE
		var is_selected=selected==("hero" if i==0 else "atang") or (mode=="sea" and selected=="ship" and i==0)
		parties[i].add_theme_stylebox_override("normal",ui_art.style("portrait_selected" if is_selected else "portrait",22))
	if mode=="port":
		objective.text="归港 · 与老梁交谈" if completed else ("备航 · 与阿棠同行" if recruited else "寻找老梁 · 与阿棠交谈")
		party_names[0].text="船主";party_names[1].text="阿棠"
		party_faces[0].texture=ui_art.head("船主");party_faces[1].texture=ui_art.head("阿棠")
		for i in range(2):ui_art.update_health(party_bars[i],1.0,real_dt)
		party_status[0].text="近战";party_status[1].text="弩手"
		hint.text="E 交谈" if port.actor.position.distance_to(companion.position)<3.0 and not recruited else ""
	elif mode=="sea":
		var ship=sea.ships[0]
		objective.text="敌船停航 · 靠近登船" if sea.ships[1].disabled else ("湾口 · 寻找老梁" if sea.state=="sailing" else "海上遭遇 · 迫停敌船")
		if sea.escape_time>0:objective.text="脱离追击 · "+str(ceili(6.0-sea.escape_time))+" 秒"
		party_names[0].text="归舟";party_names[1].text="阿棠"
		party_faces[0].texture=ui_art.icon("ship");party_faces[1].texture=ui_art.head("阿棠")
		ui_art.update_health(party_bars[0],ship.hp/ship.maximum,real_dt)
		ui_art.update_health(party_bars[1],0.0 if sea.special_used else 1.0,real_dt)
		ui_art.update_health(party_cooldowns[0],1.0-ship.reload/(6.6 if fit=="mount" else 8.0),real_dt)
		ui_art.update_health(party_cooldowns[1],0.0 if sea.special_used else 1.0,real_dt)
		party_status[0].text="装填 "+str(ceili(ship.reload))+"s" if ship.reload>0 else "舷炮就绪"
		party_status[1].text="齐射已用" if sea.special_used else ("齐射自动" if sea.special_pending else "齐射保留")
		parties[0].tooltip_text="船况 "+str(ceili(ship.hp))+" / "+str(int(ship.maximum))
		command_details.text=("船体弹" if ship.loaded=="hull" else "压制弹")+" · 下轮："+("船体弹" if ship.pending=="hull" else "压制弹")
		hint.text="点击海面航行 · 点击敌船迎战 · 右键结束指挥" if not selected.is_empty() else ""
	else:
		objective.text="救出老梁 · 制服头目" if boarding.active else ("战斗结束 · 接回老梁" if boarding.result=="won" else ("队伍倒下 · 重试本段" if boarding.result=="lost" else "登船布阵 · 选择落点"))
		for i in range(2):
			var pawn=boarding.pawns[i]
			party_faces[i].texture=ui_art.head(pawn.title);party_names[i].text=pawn.title
			ui_art.update_health(party_bars[i],pawn.hp/pawn.maximum,real_dt)
			ui_art.update_health(party_cooldowns[i],1.0-pawn.skill_cd/(8.0 if i==0 else 10.0),real_dt)
			party_faces[i].modulate=Color(0.40,0.40,0.40) if pawn.hp<=0 else Color.WHITE
			party_status[i].text="倒地" if pawn.hp<=0 else (str(ceili(pawn.skill_cd))+"s" if pawn.skill_cd>0 else "技能就绪")
			if pawn.hp>0 and pawn.weapon_class=="crossbow" and not pawn.weapon_loaded:party_status[i].text="装填" if pawn.action=="reload" else "收势"
			parties[i].tooltip_text=pawn.title+" · 生命 "+str(ceili(pawn.hp))+"/"+str(int(pawn.maximum))
		if not selected.is_empty():
			var pawn=boarding.unit(selected)
			if pawn!=null:
				command_details.text="点击甲板移动 · 点击敌人集火" if boarding.active else "在金色标记内放置队员"
				if is_instance_valid(command_skill):
					command_skill.disabled=pawn.skill_cd>0 or not pawn.action.is_empty() or pawn.cooldown>0
					command_skill.text=str(ceili(pawn.skill_cd))+"s" if pawn.skill_cd>0 else ("强攻" if selected=="hero" else "压制")
					command_skill.add_theme_stylebox_override("normal",ui_art.style("ready" if not command_skill.disabled else "normal",30))
				if is_instance_valid(command_auto):command_auto.text="技能自动" if pawn.auto_skill else "技能保留"
		hint.text=("点击甲板移动 · 点击敌人集火 · 右键结束指挥" if boarding.active else "点击金色区域放置 · 右键取消") if not selected.is_empty() else ""
	if dialog_open or paused or lost:hint.text=""
	if command_panel.visible:
		# Fit this state's actual content while keeping the same nine-slice
		# corners and safe area; a two-button panel need not be naval-order width.
		var content=command_panel.get_child(0) as Control
		var needed=content.get_combined_minimum_size()+Vector2(64,48)
		var extent=Vector2(clampf(ceilf(needed.x/4)*4,400,776),maxf(176,ceilf(needed.y/4)*4))
		_dock(command_panel,Vector2.ONE,Vector2(-extent.x-28,-extent.y-68),extent)

func _input(event: InputEvent) -> void:
	if manual_review and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F12:
		_capture("%s-%03d.png"%[mode,captures.size()])
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_TAB and mode=="deck":
		deck_overview=not deck_overview
		get_viewport().set_input_as_handled()
	# Pause is global even while a command button has GUI focus.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_E or event.keycode==KEY_ENTER:
			if dialog_open:advance_dialogue()
			elif mode=="port" and completed:show_dialogue([["老梁","人齐了，船也能走。下一趟出海，记得先来找我。"]],Callable())
			elif mode=="port" or (mode=="sea" and sea.can_board()):_main_action()
		elif event.keycode==KEY_ESCAPE:
			if paused:toggle_pause()
			elif not selected.is_empty():cancel_command()
			elif not dialog_open:toggle_pause()
		elif event.keycode==KEY_F5:retry_checkpoint()
	if not (event is InputEventMouseButton) or not event.pressed or dialog_open or lost:return
	if event.button_index==MOUSE_BUTTON_RIGHT:cancel_command();return
	if event.button_index!=MOUSE_BUTTON_LEFT or paused:return
	var point=deck_mouse_point(event.position) if mode=="deck" else screen_to_ground(event.position,0.18)
	if mode=="sea":
		if point==null:return
		if camera.unproject_position(sea.ships[0].node.position+Vector3(0,3,0)).distance_to(event.position)<90:select_ship()
		elif camera.unproject_position(sea.ships[1].node.position+Vector3(0,3,0)).distance_to(event.position)<90:sea.engage();cancel_command()
		else:sea.move_order(point);fx.ring(point,1.4,Color("d8c790"),1.2);cancel_command()
	elif mode=="deck":
		var clicked=null
		var best=52.0
		for pawn in boarding.pawns:
			var distance=camera.unproject_position(pawn.global_position+Vector3(0,0.9,0)).distance_to(event.position)
			if distance<best and pawn.hp>0:clicked=pawn;best=distance
		if clicked!=null and clicked.team==0:select_pawn(clicked.key)
		elif not selected.is_empty():
			if point==null:
				if clicked!=null and boarding.active:
					if boarding.target_order(selected,clicked.key):cancel_command()
				else:toast("此处无法到达，请选择甲板通路。")
				return
			if not boarding.active:
				if boarding.deploy(selected,point):cancel_command()
				else:toast("这里无法布阵，请选择船上可放置的位置。")
			elif clicked!=null:
				if boarding.target_order(selected,clicked.key):cancel_command()
			elif aim_mode=="move":
				if boarding.move_order(selected,point):
					fx.ring(boarding.unit(selected).goal+Vector3(0,0.03,0),0.45,Color("d8c790"),1.0)
					cancel_command()
				else:toast("此处无法到达，或通道暂时被占用。")

func deck_mouse_point(screen: Vector2):
	var from=camera.project_ray_origin(screen)
	var to=from+camera.project_ray_normal(screen)*200.0
	var query=PhysicsRayQueryParameters3D.create(from,to,16384)
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else null

func screen_to_ground(screen: Vector2,height: float):
	var origin=camera.project_ray_origin(screen)
	var direction=camera.project_ray_normal(screen)
	return Plane(Vector3.UP,height).intersects_ray(origin,direction)

func _failure(text_value: String) -> void:
	lost=true
	selected=""
	command_panel.visible=false
	toast(text_value,30)
	main_action.text="重试本段"
	_apply_time()

func _save_checkpoint(stage: String) -> void:
	checkpoint={"version":1,"stage":stage,"recruited":recruited,"fit":fit,"growth_trait":growth_trait,"completed":completed,"stopped_story":stopped_story,"sea":sea.snapshot()}
	if review:return
	var file=FileAccess.open(SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(checkpoint,"\t"))

func retry_checkpoint() -> void:
	if checkpoint.is_empty():toast("还未到检查点。先与阿棠交谈。 ");return
	dialog_open=false;choosing=false;dialog_panel.visible=false
	recruited=checkpoint.recruited;fit=checkpoint.fit;growth_trait=checkpoint.growth_trait
	completed=checkpoint.completed;stopped_story=checkpoint.stopped_story
	sea.restore(checkpoint.sea)
	var stage=checkpoint.stage
	if stage=="deck":boarding.reset(growth_trait,sea.suppressed);_switch_mode("deck")
	elif stage=="sea":_switch_mode("sea")
	else:
		_switch_mode("port")
		if completed:
			port._set_time_of_day(true)
			port.actor.position=Vector3(4.0,1.855,5.5)
			companion.position=Vector3(5.5,1.855,5.5)
			old_liang.position=Vector3(6.6,1.855,5.55)
	toast("已返回检查点。")

func _review_tick(dt: float) -> void:
	review_time+=dt
	if dialog_open:
		review_dialogue_time+=dt
		if mode=="port" and not completed and not captures.has("00-port-dialogue.png") and review_dialogue_time>0.5:_capture("00-port-dialogue.png")
		if mode=="port" and completed and not captures.has("06-return-port.png") and review_dialogue_time>0.5:_capture("06-return-port.png")
		if choosing and review_dialogue_time>1.5:
			if not recruited:recruit()
			elif fit.is_empty():choose_fit("mount")
			elif growth_trait.is_empty():choose_trait("pursuit")
		elif not choosing and review_dialogue_time>max(1.6,dialog_body.text.length()*0.065):
			review_dialogue_time=0.0
			advance_dialogue()
	if review_scene=="story" and mode=="port" and not dialog_open:
		if not recruited and mode_time>3:talk()
		elif recruited and not completed and mode_time>9:depart()
	if mode=="sea":
		if mode_time>1 and sea.ships[0].intent=="sail" and not sea.ships[1].disabled:sea.engage()
		if mode_time>4 and not captures.has("01-sea.png"):_capture("01-sea.png")
		if sea.shots.size()>0 and sea.shots[0].life<4.75 and not captures.has("02-projectiles.png"):
			select_ship();_capture("02-projectiles.png");review_step=1
		if review_step==1 and fmod(review_time,5.0)<dt:cancel_command();review_step=2
		if sea.can_board() and not growth_trait.is_empty() and not dialog_open:enter_boarding()
	if mode=="deck":
		if mode_time>1 and not captures.has("03-deploy.png"):_capture("03-deploy.png")
		if mode_time>3 and not boarding.active and boarding.result.is_empty():begin_boarding()
		if mode_time>8 and not captures.has("04-boarding.png"):_capture("04-boarding.png")
		if mode_time>12 and not captures.has("05-command.png"):select_pawn("atang");_capture("05-command.png")
		if mode_time>15 and not selected.is_empty():cancel_command()
	if review_scene=="deck" and (mode_time>42 or completed):_finish_review()
	elif review_scene=="sea" and review_time>55:_finish_review()
	elif review_scene=="story" and ((completed and not dialog_open) or review_time>220):_finish_review()

func _capture(filename: String) -> void:
	captures.append(filename)
	_update_ui()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(review_dir.path_join(filename))

func _finish_review() -> void:
	var file=FileAccess.open(review_dir.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"completed":completed,"seconds":review_time,"captures":captures,"projectiles_launched":sea.launched,"projectile_hits":sea.impacts,"water_misses":sea.misses,"boarding_hits":boarding.hits,"source":"Actual Godot runtime; temporary retained character art, not accepted new character animations"},"\t"))
	Engine.time_scale=1.0
	get_tree().quit()

func _exit_tree() -> void:
	Engine.time_scale=1.0
