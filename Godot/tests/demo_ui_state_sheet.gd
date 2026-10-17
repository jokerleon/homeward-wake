extends SceneTree
const UIArt=preload("res://scripts/demo/ui_art.gd")
var art=UIArt.new()
var gui
var font

func _initialize() -> void:run.call_deferred()
func label(text: String,at: Vector2,extent: Vector2,size: int=20) -> Label:
	var result=Label.new();result.text=text;result.position=at;result.size=extent
	result.add_theme_font_override("font",font);result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("e8d9b7"));gui.add_child(result)
	return result

func run() -> void:
	font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	gui=Control.new();root.add_child(gui);gui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop=ColorRect.new();backdrop.color=Color("182d33");gui.add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label("归港的人 · 图形 UI 状态与九宫格尺寸",Vector2(64,34),Vector2(1450,45),28)
	label("同一角饰与内容安全区，改变宽度时只伸展边缘和中心",Vector2(64,83),Vector2(1450,32),18)
	var names=["正常","悬停","按下","禁用","就绪","危险"]
	var skins=["normal","hover","pressed","disabled","ready","danger"]
	for i in range(6):
		var y=138+i*76
		label(names[i],Vector2(64,y+12),Vector2(160,32))
		for j in range(2):
			var button=Button.new();button.text="执行指令" if j==0 else "改良炮架 · 装填更快"
			button.add_theme_font_override("font",font);art.decorate_button(button,"cannon" if j==0 else "mount")
			button.add_theme_stylebox_override("normal",art.style(skins[i]));button.disabled=i==3
			button.position=Vector2(260 if j==0 else 550,y);button.size=Vector2(240 if j==0 else 430,56)
			button.mouse_filter=Control.MOUSE_FILTER_IGNORE;gui.add_child(button)
	for i in range(2):
		var panel=PanelContainer.new();panel.position=Vector2(1110+i*174,150);panel.size=Vector2(140,178)
		panel.add_theme_stylebox_override("panel",art.style("portrait_selected" if i==1 else "portrait"));gui.add_child(panel)
		var content=VBoxContainer.new();content.add_theme_constant_override("separation",4);panel.add_child(content)
		var face=art.picture(content,art.head("船主" if i==0 else "阿棠"),Vector2.ZERO,Vector2(112,112));face.custom_minimum_size.y=112
		var name=Label.new();name.text="船主" if i==0 else "阿棠";name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_override("font",font);name.add_theme_font_size_override("font_size",18);content.add_child(name)
	label("头像／选中态",Vector2(1110,349),Vector2(320,32))
	for i in range(3):
		label(["空","半满","满"][i],Vector2(64,642+i*52),Vector2(160,32))
		for j in range(2):
			var bar=art.health(gui,Vector2(260 if j==0 else 550,648+i*52),Vector2(240 if j==0 else 430,18))
			bar.ratio=i*0.5;art.update_health(bar,i*0.5,0)
	label("外框保持尺寸；生命／冷却只改变内部填充。暂停与对白隐藏整组控件。",Vector2(64,826),Vector2(1450,32),18)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Work/project/joker/chess/Artifacts/ReturnDemo/ui-final-20261012/state-sheet.png")
	quit()
