## Juice — hit-stop and shake requests, autoloaded as `Juice`.
##
## Feedback that is global by nature: a freeze frame is not something a hitbox
## can own, and the camera should not have to know which hurtbox was struck.
## Listens for Events.impact and translates it into feel.
##
## process_mode is ALWAYS (set in project.godot) so that ending the run — which
## pauses the tree — cannot strand Engine.time_scale at 0.05 forever.
extends Node

signal shake_requested(strength: float)

@export_group("Hit stop")
## Seconds of near-freeze when a blow lands. Long enough to read, short enough
## not to feel like a stutter.
@export_range(0.0, 0.3, 0.005) var hit_stop_seconds := 0.055
@export_range(0.01, 1.0, 0.01) var hit_stop_scale := 0.06
## Blocked hits get a shorter freeze — a parry should feel crisp, not heavy.
@export_range(0.0, 0.3, 0.005) var blocked_stop_seconds := 0.03

@export_group("Shake")
@export_range(0.0, 1.0, 0.01) var shake_on_hit_dealt := 0.22
@export_range(0.0, 1.0, 0.01) var shake_on_hit_taken := 0.55
@export_range(0.0, 1.0, 0.01) var shake_on_block := 0.25

## Spark puff spawned at each impact.
@export var burst_scene: PackedScene = preload("res://scenes/fx/impact_burst.tscn")

var _resume_at_ms := 0


func _ready() -> void:
	Events.impact.connect(_on_impact)
	Run.ended.connect(func(_o: String, _s: Dictionary) -> void: _clear_hit_stop())


func _process(_delta: float) -> void:
	# Real milliseconds, not delta: delta is scaled by the very thing we are
	# waiting to undo, so counting it down would take 16x too long.
	if _resume_at_ms > 0 and Time.get_ticks_msec() >= _resume_at_ms:
		_clear_hit_stop()


func hit_stop(seconds: float, scale: float) -> void:
	if seconds <= 0.0:
		return
	Engine.time_scale = scale
	_resume_at_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func shake(strength: float) -> void:
	shake_requested.emit(strength)


## Parented to the current scene, not to this autoload: an autoload persists
## across scene reloads and would accumulate every spark ever emitted.
func _burst(where: Vector3) -> void:
	if burst_scene == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst: Node3D = burst_scene.instantiate()
	scene.add_child(burst)
	burst.global_position = where


func _clear_hit_stop() -> void:
	_resume_at_ms = 0
	Engine.time_scale = 1.0


func _on_impact(where: Vector3, _damage: float, blocked: bool, on_player: bool) -> void:
	_burst(where)
	if blocked:
		hit_stop(blocked_stop_seconds, hit_stop_scale)
		shake(shake_on_block)
		return

	hit_stop(hit_stop_seconds, hit_stop_scale)
	shake(shake_on_hit_taken if on_player else shake_on_hit_dealt)
