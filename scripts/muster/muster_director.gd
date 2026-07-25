## MusterDirector — the pressure.
##
## Sits inert until the alarm, then spawns waves that get bigger and arrive
## sooner. It never decides where the player is or what a wave does when it
## lands; it only decides that one exists.
##
## Spawn points are found by GROUP rather than by an exported array, because a
## hand-written .tscn cannot express Array[Node3D] cleanly and because adding a
## spawn point should be "drop a Marker3D in the group", not "edit the director".
class_name MusterDirector
extends Node

@export var enemy_scene: PackedScene
@export var rider_scene: PackedScene
## Where spawned levy appear, and where the rider runs to.
@export var spawn_group := "spawn_point"
## Where the rider starts. He carries the message OUT of the monastery, so he
## must not spawn at the map edge like the levy do.
@export var rider_spawn_group := "rider_start"

@export_group("Escalation")
## Grace period after the bell before the first wave shows up.
@export_range(0.0, 120.0, 0.5) var first_wave_delay := 14.0
## Gap before wave 2. Every wave after that is `interval_decay` of the last.
@export_range(2.0, 180.0, 0.5) var wave_interval := 34.0
@export_range(0.3, 1.0, 0.01) var interval_decay := 0.82
@export_range(2.0, 60.0, 0.5) var min_interval := 11.0
@export_range(1, 10) var first_wave_count := 1
## Extra bodies added per wave.
@export_range(0, 5) var count_growth := 1
## Hard ceiling on living spawned levy, so a long run does not become a
## slideshow. Waves still tick; they just come up short.
@export_range(1, 60) var max_alive := 14

var wave := 0

var _armed := false
var _timer := 0.0
var _interval := 0.0
var _spawned: Array[Node3D] = []
var _rider_sent := false


func _ready() -> void:
	Events.alarm_raised.connect(_on_alarm_raised)
	set_physics_process(false)


func alive_count() -> int:
	# Not .filter(): it returns an untyped Array, which cannot be assigned back
	# to Array[Node3D] and throws at runtime rather than at parse time.
	var living: Array[Node3D] = []
	for enemy in _spawned:
		if is_instance_valid(enemy):
			living.append(enemy)
	_spawned = living
	return _spawned.size()


func _on_alarm_raised(_where: Vector3) -> void:
	if _armed:
		return
	_armed = true
	_timer = first_wave_delay
	_interval = wave_interval
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if Run.finished:
		set_physics_process(false)
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_send_wave()
	_timer = _interval
	_interval = maxf(min_interval, _interval * interval_decay)


func _send_wave() -> void:
	wave += 1

	# The rider goes out with the first wave: killing him is a chance to keep
	# the clock, not a thing you can pre-empt.
	if not _rider_sent and rider_scene != null:
		_rider_sent = true
		_spawn(rider_scene, rider_spawn_group)

	var wanted := first_wave_count + count_growth * (wave - 1)
	var room := max_alive - alive_count()
	var count := clampi(wanted, 0, room)

	for i in count:
		_spawn(enemy_scene)

	Events.wave_spawned.emit(wave, count)


func _spawn(scene: PackedScene, group := "") -> void:
	var points := get_tree().get_nodes_in_group(group if group != "" else spawn_group)
	if points.is_empty() or scene == null:
		push_warning("MusterDirector: no spawn points in group '%s'" % (group if group != "" else spawn_group))
		return

	var point: Node3D = points.pick_random()
	var enemy: Node3D = scene.instantiate()
	# Add to the same parent the spawn point lives under, so spawned bodies end
	# up beside the level rather than parented to the director.
	point.get_parent().add_child(enemy)
	enemy.global_position = point.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	_spawned.append(enemy)
