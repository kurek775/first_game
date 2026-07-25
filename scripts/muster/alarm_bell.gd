## AlarmBell — turns "you have been noticed" into a single world event.
##
## Rings on either of two triggers: a monk sees you (any Perception anywhere
## reports it on the bus), or you walk right up to the bell yourself. Fires at
## most once per run, because everything downstream escalates and a bell that
## can ring twice would double the muster.
class_name AlarmBell
extends Area3D

signal rung

## Ring if the player walks within the trigger volume, on the fiction that a
## monk beat you to the rope.
@export var ring_on_proximity := true
## Ring when any enemy anywhere reports seeing the player.
@export var ring_on_spotted := true

var _rung := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if ring_on_spotted:
		Events.player_spotted.connect(func(_who: Node3D) -> void: ring())


func has_rung() -> bool:
	return _rung


func ring() -> void:
	if _rung:
		return
	_rung = true
	rung.emit()
	Events.alarm_raised.emit(global_position)


func _on_body_entered(body: Node3D) -> void:
	if ring_on_proximity and body.is_in_group("player"):
		ring()
