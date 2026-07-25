## MeleeAttack — the swing timeline.
##
## windup -> active -> recovery, driving the Hitbox on for exactly the active
## window. Separating the three means "the swing is slow to start but hard to
## punish" is a tuning change, not a code change.
##
## Driven by a countdown in _physics_process rather than `await` on timers: a
## swing has to be cancellable the instant a hit staggers you, and dangling
## awaits that resume into a cancelled state are a bad way to find that out.

class_name MeleeAttack
extends Node

signal swing_started
signal swing_landed(hurtbox: Hurtbox)
signal swing_finished
signal swing_cancelled

enum Phase {
	IDLE,
	WINDUP,   ## committed, hitbox still cold
	ACTIVE,   ## hitbox live
	RECOVERY, ## vulnerable, cannot act
}

@export var hitbox: Hitbox

@export_group("Timing")
## Seconds before the blade goes live. Raise it to make attacks readable.
@export_range(0.0, 1.5, 0.01) var windup := 0.18
## Seconds the hitbox stays live.
@export_range(0.02, 1.0, 0.01) var active := 0.12
## Seconds locked in place afterwards. This is the punish window.
@export_range(0.0, 2.0, 0.01) var recovery := 0.35

@export_group("Movement")
## Speed multiplier while swinging.
@export_range(0.0, 1.0, 0.05) var move_scale := 0.35

var phase := Phase.IDLE

var _timer := 0.0


func _ready() -> void:
	if hitbox != null:
		hitbox.hit_landed.connect(_on_hit_landed)


func is_swinging() -> bool:
	return phase != Phase.IDLE


func can_swing() -> bool:
	return phase == Phase.IDLE


func try_swing() -> bool:
	if not can_swing():
		return false
	phase = Phase.WINDUP
	_timer = windup
	swing_started.emit()
	return true


## Abandon the swing wherever it is. Used when a hit staggers us.
func cancel() -> void:
	if phase == Phase.IDLE:
		return
	if hitbox != null:
		hitbox.deactivate()
	phase = Phase.IDLE
	_timer = 0.0
	swing_cancelled.emit()


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	match phase:
		Phase.WINDUP:
			phase = Phase.ACTIVE
			_timer = active
			if hitbox != null:
				hitbox.activate()
		Phase.ACTIVE:
			if hitbox != null:
				hitbox.deactivate()
			phase = Phase.RECOVERY
			_timer = recovery
		Phase.RECOVERY:
			phase = Phase.IDLE
			_timer = 0.0
			swing_finished.emit()


func _on_hit_landed(hurtbox: Hurtbox, _hit: HitInfo) -> void:
	swing_landed.emit(hurtbox)
