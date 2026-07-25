## Health — a pool of hit points and nothing else.
##
## Deliberately ignorant of hitboxes, blocking, knockback and who dealt the
## damage. That is what lets the player, the training dummy and stage 4's enemy
## all use this same node without a single conditional.

class_name Health
extends Node

signal damaged(amount: float, remaining: float)
signal healed(amount: float, remaining: float)
signal died

@export var max_health := 100.0
## Flip this on to test attacks without dying. Also useful for the dummy.
@export var invulnerable := false

var current := 0.0

var _dead := false


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return _dead


## 0.0 .. 1.0, for health bars.
func fraction() -> float:
	return current / max_health if max_health > 0.0 else 0.0


func apply_damage(amount: float) -> void:
	if _dead or invulnerable or amount <= 0.0:
		return

	current = maxf(0.0, current - amount)
	damaged.emit(amount, current)

	if is_zero_approx(current):
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current = minf(max_health, current + amount)
	healed.emit(amount, current)


## Back to full and alive. Handy for the dummy so you can keep hitting it.
func reset() -> void:
	_dead = false
	current = max_health
