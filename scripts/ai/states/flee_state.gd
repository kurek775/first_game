## Flee — get off the island and tell the levy where the raiders are.
##
## The rider's whole purpose. He does not fight, he does not care that you are
## chasing him; he runs for the nearest escape marker and, if he reaches it,
## takes 90 seconds off your clock.
extends State

## Marker group to run toward.
@export var exit_group := "escape_point"
## How close counts as gone.
@export_range(0.5, 20.0, 0.5) var arrive_distance := 3.0

var _exit: Node3D


func enter() -> void:
	_exit = _nearest_exit()


func tick(delta: float) -> void:
	# Knockback still lands on him — hitting the rider genuinely delays him,
	# which is the only reason chasing him is worth trying.
	if actor.reaction.is_staggered():
		actor.stop()
		return

	if _exit == null:
		_exit = _nearest_exit()
		if _exit == null:
			actor.stop()
			return

	var goal := _exit.global_position
	actor.move_toward_point(goal)
	actor.face(goal, delta)

	if actor.global_position.distance_to(goal) <= arrive_distance:
		Events.rider_escaped.emit()
		actor.queue_free()


func _nearest_exit() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in actor.get_tree().get_nodes_in_group(exit_group):
		var marker := node as Node3D
		if marker == null:
			continue
		var distance := actor.global_position.distance_to(marker.global_position)
		if distance < best_distance:
			best_distance = distance
			best = marker
	return best
