extends Node
## Headless/automated walkthrough (the demo's window.__ym checks): `-- --shots=<dir>` boots, then visits the intro, flight,
## a hotspot, the card, the 舆图 (+ trail, search) and the debug panel, saving a PNG of each, then quits.
## Run: godot --path godot -- --shots=/tmp/shots --skip-intro

var dir := ""
var tour := false

## `-- --tour=<dir>`: a terrain tour instead — one shot over each landform region (compare `--terrain=…` runs with the
## exported land). [place id, altitude 丈, camera offset south 丈]
const TOUR := [["yunmeng", 2600.0, 2600.0], ["gujian", 1500.0, 1200.0], ["luoyun", 1650.0, 1500.0], ["zimu", 1300.0, 900.0],
	["baiqiao", 2200.0, 2000.0], ["sunshi", 1500.0, 1200.0], ["lingyan", 1600.0, 1300.0], ["swamp", 1800.0, 1600.0],
	["yunzhoucheng", 2600.0, 5200.0], ["minzhou", 2200.0, 2000.0], ["luanming", 2400.0, 2600.0], ["nihang", 2400.0, 2400.0],
	["shuiying", 2400.0, 2600.0], ["qiling", 3200.0, 3000.0]]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
		elif a.begins_with("--tour="):
			dir = a.substr(7); tour = true
	if dir == "":
		queue_free()
		return
	DirAccess.make_dir_recursive_absolute(dir)
	while Game.mode == Game.Mode.LOADING:
		await get_tree().process_frame
	var d := UIUtil.director()
	if tour:
		d.finish_intro()
		for t in TOUR:
			if World.by_id.has(t[0]):
				await _fly(d, t[0], t[1], t[2], 2.0)
				await _shot("tour_" + t[0])
		get_tree().quit()
		return
	await _wait(1.0)
	await _shot("01_intro")
	d.finish_intro()
	await _fly(d, "yunmeng", 1650.0, 320.0, 1.5)
	await _shot("02_flight_yunmeng")
	await _fly(d, "luoyun", 900.0, 240.0, 1.5)
	await _shot("03_flight_low_hotspot")
	await _fly(d, "gujian", 2600.0, 320.0, 1.5)
	await _shot("04_flight_high")
	Game.open_card(World.by_name["落云宗"], false)
	await _wait(0.8)
	await _shot("05_info_card")
	Game.close_card()
	d.start_transition(Game.Mode.MAP)
	await _until(func(): return d.trans > 0.5)
	await _shot("06a_to_map")
	await _until(func(): return Game.mode == Game.Mode.MAP)
	await _frames(30)
	await _shot("06_map")
	d.map_home_view()
	await _until(func(): return d.map_goal == null)
	await _shot("06b_map_home")
	get_tree().get_first_node_in_group("director")
	var chrome := get_tree().root.find_child("MapChrome", true, false)
	if chrome:
		chrome.get_node("%BtnTrail").button_pressed = true
		await _wait(0.3)
		await _shot("07_map_trail")
		var q: LineEdit = chrome.get_node("%Q")
		q.text = "落"
		q.text_changed.emit("落")
		await _wait(0.3)
		await _shot("08_map_search")
	d.toggle_map()
	await _until(func(): return Game.mode == Game.Mode.FLIGHT)
	var dbg := get_tree().root.find_child("Debug", true, false)
	if dbg:
		dbg._toggle(true)
	await _wait(0.6)
	await _shot("09_debug_panel")
	get_tree().quit()


func _fly(d: Node, id: String, A: float, dz: float, secs: float) -> void:
	var p: Dictionary = World.by_id[id]
	d.pos = Vector3(p.x, 0, p.z + dz); d.vel = Vector3.ZERO
	d.A = A; d.At = A; d.a_eff = A; d.rig_target = d.pos
	d.clear = World.ground_clear(d.pos.x, d.pos.z)
	if Game.mode != Game.Mode.FLIGHT:
		Game.mode = Game.Mode.FLIGHT
	await _wait(secs)


func _until(cond: Callable, max_frames := 3000) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().process_frame
		n += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot ", name)
