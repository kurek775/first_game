## HealthLabel — floats a hit-point readout over a body.
##
## A debug affordance, not the shipping HUD: it makes "did that swing actually
## connect, and for how much" answerable at a glance instead of by reading a
## log. Delete or hide it once combat numbers are settled.

extends Label3D

@export var health: Health


func _ready() -> void:
	if health == null:
		text = "no health node"
		return
	health.damaged.connect(_on_changed)
	health.healed.connect(_on_changed)
	health.died.connect(_refresh)
	_refresh()


func _on_changed(_amount: float, _remaining: float) -> void:
	_refresh()


func _refresh() -> void:
	if health.is_dead():
		text = "DEAD"
		modulate = Color(0.6, 0.6, 0.6)
		return
	text = "%d / %d" % [roundi(health.current), roundi(health.max_health)]
	# Green through to red as it drains.
	modulate = Color(1.0, 0.25 + health.fraction() * 0.75, 0.3)
