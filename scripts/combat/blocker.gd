## Blocker — owns the rule for what a raised guard actually stops.
##
## The rule lives here rather than in Hurtbox so that changing "blocking is
## frontal only" into "blocking costs stamina" or "blocking has a parry window"
## touches exactly one file.

class_name Blocker
extends Node

signal block_changed(blocking: bool)
signal blocked(hit: HitInfo)

## What counts as "forward". Point this at the Visual node, since that is what
## rotates to face the way the character is looking.
@export var facing: Node3D

## Total cone the guard covers, centred on forward. 120 means 60 degrees to
## either side; a blow from further round the side gets through.
@export_range(0.0, 360.0, 5.0) var block_arc_deg := 120.0

## Fraction of damage that still gets through a successful block.
## Knockback reduction is NOT here — it lives on HitReaction, which is the
## thing that applies knockback. Each component reduces only what it applies.
@export_range(0.0, 1.0, 0.05) var chip_damage_fraction := 0.15

## Movement speed multiplier while the guard is up.
@export_range(0.0, 1.0, 0.05) var move_scale := 0.45

var _blocking := false


func is_blocking() -> bool:
	return _blocking


func set_blocking(value: bool) -> void:
	if value == _blocking:
		return
	_blocking = value
	block_changed.emit(_blocking)


## True if a raised guard stops this blow. Called by Hurtbox before it applies
## anything, so a false answer means the hit lands in full.
func blocks(hit: HitInfo) -> bool:
	if not _blocking:
		return false
	if facing == null:
		return true

	var to_attacker := hit.origin - facing.global_position
	to_attacker.y = 0.0
	# Struck from exactly on top of us — no meaningful direction, let it block.
	if to_attacker.length_squared() < 0.0001:
		return true

	var forward := -facing.global_transform.basis.z
	forward.y = 0.0

	return rad_to_deg(forward.angle_to(to_attacker)) <= block_arc_deg * 0.5


## Called by Hurtbox once it has decided the blow was blocked, so the Blocker
## can announce it (for shield sparks, stamina drain, camera shake later).
func absorb(hit: HitInfo) -> void:
	blocked.emit(hit)
