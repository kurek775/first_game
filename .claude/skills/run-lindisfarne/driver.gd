## Agent driver for the Lindisfarne greybox.
##
## Instantiates a game scene as a child of itself, runs a small semicolon-
## separated command program against it, saves PNG screenshots, and dumps a
## JSON state log. Nothing here is game code — it exists so an agent can drive
## the running app without a human at the keyboard.
##
## Run it as the main scene (see SKILL.md):
##   godot .claude/skills/run-lindisfarne/driver.tscn -- --do="..." --shots=DIR
##
## Commands (separated by ";"):
##   wait <seconds>          let the game run
##   shot <name>             save <shots>/<name>.png
##   press <action>          hold an input action (move_forward, sprint, ...)
##   release <action>        release it
##   tap <action> <seconds>  press, wait, release
##   tp <x> <y> <z>          teleport the player, zero its velocity
##   yaw <degrees>           set camera rig yaw directly
##   pitch <degrees>         set spring-arm pitch directly
##   mouse <dx> <dy>         inject real mouse motion through camera_rig.gd
##   note <text>             label the next log entry
extends Node

var _scene_path := "res://scenes/main.tscn"
var _shots_dir := "user://shots"
var _program := "wait 0.5; shot boot"
var _log_path := ""
var _capture_mouse := false

var _game: Node
var _player: CharacterBody3D
var _rig: Node3D
var _arm: SpringArm3D
var _motor: Node
var _hud_label: Label

var _held: Array[String] = []
var _entries: Array = []
var _note := ""
var _failed := false


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))

	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("driver: cannot load scene %s" % _scene_path)
		get_tree().quit(2)
		return

	_game = packed.instantiate()
	add_child(_game)
	# Two frames: one for the tree to enter, one for the first physics tick.
	await get_tree().process_frame
	await get_tree().process_frame

	if not _bind_nodes():
		get_tree().quit(3)
		return

	# Default to NOT stealing the cursor — a human may be at this display.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _capture_mouse else Input.MOUSE_MODE_VISIBLE

	for statement in _program.split(";", false):
		await _exec(statement.strip_edges())

	_release_all()
	_write_log()
	print("DRIVER done shots=%s entries=%d" % [
		ProjectSettings.globalize_path(_shots_dir), _entries.size(),
	])
	get_tree().quit(1 if _failed else 0)


func _bind_nodes() -> bool:
	_player = _game.find_child("Player", true, false) as CharacterBody3D
	if _player == null:
		push_error("driver: no CharacterBody3D named 'Player' inside %s" % _scene_path)
		return false
	_rig = _player.get_node_or_null("CameraRig") as Node3D
	_arm = _player.get_node_or_null("CameraRig/SpringArm3D") as SpringArm3D
	_motor = _player.get_node_or_null("Motor")
	_hud_label = _game.find_child("Label", true, false) as Label
	return true


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--do="):
			_program = arg.substr(5)
		elif arg.begins_with("--shots="):
			_shots_dir = arg.substr(8).rstrip("/")
		elif arg.begins_with("--scene="):
			_scene_path = arg.substr(8)
		elif arg.begins_with("--log="):
			_log_path = arg.substr(6)
		elif arg == "--capture-mouse":
			_capture_mouse = true
		else:
			push_error("driver: unknown argument '%s'" % arg)
			_failed = true


func _exec(statement: String) -> void:
	if statement.is_empty():
		return
	var parts := statement.split(" ", false)
	var cmd := parts[0]

	match cmd:
		"wait":
			await _wait(float(parts[1]))
		"shot":
			await _shot(parts[1])
		"press":
			_press(parts[1])
		"release":
			_release(parts[1])
		"tap":
			_press(parts[1])
			await _wait(float(parts[2]))
			_release(parts[1])
		"tp":
			_player.global_position = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
			_player.velocity = Vector3.ZERO
		"yaw":
			_rig.rotation.y = deg_to_rad(float(parts[1]))
		"pitch":
			_arm.rotation.x = deg_to_rad(float(parts[1]))
		"mouse":
			await _mouse(float(parts[1]), float(parts[2]))
		"note":
			_note = " ".join(parts.slice(1))
		_:
			push_error("driver: unknown command '%s'" % cmd)
			_failed = true
			return

	_record(statement)


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		elapsed += get_process_delta_time()
		await get_tree().process_frame


func _press(action: String) -> void:
	if not InputMap.has_action(action):
		push_error("driver: no such input action '%s'" % action)
		_failed = true
		return
	Input.action_press(action)
	if action not in _held:
		_held.append(action)


func _release(action: String) -> void:
	Input.action_release(action)
	_held.erase(action)


func _release_all() -> void:
	for action in _held.duplicate():
		Input.action_release(action)
	_held.clear()


## Injects motion through the real _unhandled_input path in camera_rig.gd, so
## this exercises the actual mouse-look code rather than poking rotations.
## The rig ignores motion unless the mouse is captured, so capture across the
## injection and hand the cursor back afterwards.
func _mouse(dx: float, dy: float) -> void:
	var previous := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	Input.parse_input_event(event)

	# parse_input_event is deferred to the next input flush; give it two frames
	# to actually reach _unhandled_input before handing the cursor back.
	await get_tree().process_frame
	await get_tree().process_frame
	Input.mouse_mode = previous


func _shot(shot_name: String) -> void:
	# --headless uses the dummy renderer, which never draws, so frame_post_draw
	# never fires and awaiting it deadlocks the driver forever. Degrade to a
	# state-log-only run instead of hanging.
	if DisplayServer.get_name() == "headless":
		push_warning("driver: headless renderer cannot screenshot; skipping '%s'" % shot_name)
		return

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shots_dir, shot_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("driver: could not save %s (error %d)" % [path, err])
		_failed = true


func _state() -> Dictionary:
	var pos: Vector3 = _player.global_position
	var state := {
		"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"grounded": _player.is_on_floor(),
		"visual_visible": _player.get_node("Visual").visible,
		"held": _held.duplicate(),
	}
	if _motor != null:
		state["speed"] = snappedf(_motor.get_ground_speed(), 0.01)
		state["sprinting"] = _motor.is_sprinting()
	if _rig != null:
		state["yaw_deg"] = snappedf(rad_to_deg(_rig.rotation.y), 0.1)
	if _arm != null:
		state["pitch_deg"] = snappedf(rad_to_deg(_arm.rotation.x), 0.1)
		state["arm_length"] = snappedf(_arm.get_hit_length(), 0.01)
	if _hud_label != null:
		state["hud"] = _hud_label.text.replace("\n", " | ")
	return state


func _record(statement: String) -> void:
	var entry := _state()
	entry["cmd"] = statement
	if not _note.is_empty():
		entry["note"] = _note
		_note = ""
	_entries.append(entry)
	print("DRIVER %-28s %s" % [statement, JSON.stringify(entry)])


func _write_log() -> void:
	if _log_path.is_empty():
		return
	var file := FileAccess.open(_log_path, FileAccess.WRITE)
	if file == null:
		push_error("driver: cannot write log to %s" % _log_path)
		_failed = true
		return
	file.store_string(JSON.stringify(_entries, "  "))
	file.close()
