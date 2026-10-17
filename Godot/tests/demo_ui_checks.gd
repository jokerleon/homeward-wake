extends SceneTree
var demo
var failures=[]
var checks=0
var state_name=""

func _initialize() -> void:run.call_deferred()
func contains(outer: Rect2,inner: Rect2,label: String) -> void:
	checks+=1
	if not outer.grow(1.0).encloses(inner):failures.append({"state":state_name,"node":label,"outer":str(outer),"inner":str(inner)})

func inspect(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is PanelContainer:
		var box=node.get_theme_stylebox("panel")
		var area=node.get_global_rect()
		area.position+=Vector2(box.get_content_margin(SIDE_LEFT),box.get_content_margin(SIDE_TOP))
		area.size-=Vector2(box.get_content_margin(SIDE_LEFT)+box.get_content_margin(SIDE_RIGHT),box.get_content_margin(SIDE_TOP)+box.get_content_margin(SIDE_BOTTOM))
		for child in node.get_children():
			if child is Control and child.visible:contains(area,child.get_global_rect(),str(child.get_path()))
	if node is BoxContainer:
		var previous: Rect2
		var has_previous=false
		for child in node.get_children():
			if not child is Control or not child.visible:continue
			var rect=child.get_global_rect()
			contains(node.get_global_rect(),rect,str(child.get_path()))
			checks+=1
			if has_previous and previous.intersects(rect) and previous.size.x>1 and previous.size.y>1 and rect.size.x>1 and rect.size.y>1:
				failures.append({"state":state_name,"overlap":str(child.get_path())})
			previous=rect;has_previous=true
	if node is Button and node.icon!=null and not node.text.is_empty():
		var box=node.get_theme_stylebox("normal")
		var available=node.size.x-box.get_content_margin(SIDE_LEFT)-box.get_content_margin(SIDE_RIGHT)
		var text_width=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
		var required=text_width+node.icon.get_width()+node.get_theme_constant("h_separation")
		checks+=1
		if available+1<required:failures.append({"state":state_name,"icon_squeezed_by_text":str(node.get_path()),"available":available,"required":required})
	for child in node.get_children():inspect(child)

func audit(label: String) -> void:
	state_name=label
	demo._update_ui()
	await process_frame;await process_frame
	for child in demo.gui.get_children():
		if child is Control and child.visible:contains(demo.gui.get_global_rect(),child.get_global_rect(),str(child.get_path()))
	inspect(demo.gui)
	if demo.paused or demo.dialog_open:
		for bar in demo.party_bars+demo.party_cooldowns:
			checks+=1
			if bar.fill.visible or bar.trail.visible:failures.append({"state":label,"bar_visible_without_frame":true})

func run() -> void:
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true
	demo.review_dir="D:/Work/project/joker/chess/Local/ReturnDemo";root.add_child(demo)
	demo.set_process(false);demo.set_physics_process(false)
	for extent in [Vector2i(1600,900),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=extent
		var tag=str(extent)
		demo.show_dialogue([["船主","旧沈砚风格基准、稳定跟随和九宫格内容安全区。"]],Callable())
		await audit(tag+" dialogue")
		demo.choice("阿棠","选择出航前的改装。",[["加固船体 · 船况 +40",Callable()],["改良炮架 · 装填更快",Callable()]])
		await audit(tag+" long choices")
		demo._close_choice();demo.recruited=true;demo.fit="mount";demo._switch_mode("port")
		await audit(tag+" exploration")
		demo.growth_trait="pursuit";demo.enter_boarding();demo.select_pawn("atang")
		await audit(tag+" deployment")
		demo.begin_boarding();demo.select_pawn("atang")
		await audit(tag+" character orders")
		demo._switch_mode("sea");demo.sea.reset("mount");demo.select_ship()
		await audit(tag+" naval orders")
		demo.cancel_command();demo.toggle_pause()
		await audit(tag+" pause")
		demo.show_journal()
		await audit(tag+" journal")
		demo.journal_panel.visible=false;demo.toggle_pause()
	FileAccess.open("D:/Work/project/joker/chess/Local/ReturnDemo/ui-layout-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("UI_LAYOUT_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
