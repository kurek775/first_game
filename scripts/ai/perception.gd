## Perception — "can I see the target, and how far away is it".
##
## Its own node so the states do not each re-implement sight, and so the whole
## question "why did that enemy notice me through a wall" has exactly one file
## to look in.

class_name Perception
extends Node

signal target_spotted(target: Node3D)
signal target_lost

@export var body: Node3D
## Where the eyes are. Raycasts start here, not at the feet, or every wall
## the enemy stands behind reads as clear line of sight over the top.
@export var eyes: Node3D
## What counts as forward, for the sight cone.
@export var facing: Node3D

@export_group("Sight")
@export var target_group := "player"
@export_range(1.0, 100.0, 0.5) var sight_range := 24.0
## Total cone in degrees. Generous by default — a raider is conspicuous.
@export_range(10.0, 360.0, 5.0) var sight_arc_deg := 200.0
## Layers that block line of sight. 1 = world geometry.
@export_flags_3d_physics var obstruction_mask := 1
## Height above the target's origin to aim the check at, so a crouching or
## sunken target is not missed by a ray at ankle level.
@export var target_eye_height := 1.2

var target: Node3D

var _visible := false


func _physics_process(_delta: float) -> void:
	target = get_tree().get_first_node_in_group(target_group) as Node3D

	var now := _evaluate()
	if now == _visible:
		return
	_visible = now
	if now:
		target_spotted.emit(target)
	else:
		target_lost.emit()


func can_see() -> bool:
	return _visible


func distance_to_target() -> float:
	if target == null or body == null:
		return INF
	return body.global_position.distance_to(target.global_position)


func target_position() -> Vector3:
	return target.global_position if target != null else Vector3.ZERO


func _evaluate() -> bool:
	if target == null or body == null or eyes == null:
		return false
	if distance_to_target() > sight_range:
		return false
	if not _within_arc():
		return false
	return _has_line_of_sight()


func _within_arc() -> bool:
	if facing == null:
		return true
	var to_target := target.global_position - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true
	var forward := -facing.global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to_target)) <= sight_arc_deg * 0.5


func _has_line_of_sight() -> bool:
	var from := eyes.global_position
	var to := target.global_position + Vector3.UP * target_eye_height

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = obstruction_mask
	# Only world geometry blocks sight, so nothing else needs excluding — but
	# be explicit, since the enemy's own body sits on a different layer only by
	# convention.
	query.exclude = [body.get_rid()] if body is CollisionObject3D else []

	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()
