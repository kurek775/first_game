## Hurtbox — the receiving end of a blow.
##
## Its whole job is routing: ask the Blocker whether the hit is stopped, apply
## the resulting damage to Health, and announce the outcome so that reactions,
## HUD and effects can respond. It decides nothing about how much a block
## reduces or how knockback feels; those live in Blocker and HitReaction.
##
## Sits on collision layer 4 ("hurtbox") and masks nothing — hurtboxes never
## look for anything, hitboxes look for them.

class_name Hurtbox
extends Area3D

## Full hit landed, after any blocking was declined.
signal hit_taken(hit: HitInfo)
## Guard stopped it. Chip damage may still have been applied.
signal hit_blocked(hit: HitInfo)

## The body this hurtbox protects. An attacker compares this against itself so
## a swing can never hit its own owner.
@export var body: Node3D
@export var health: Health
## Optional. No Blocker means this thing simply cannot block.
@export var blocker: Blocker


## Called by Hitbox. Not a signal, because the hitbox needs this to happen
## synchronously during its overlap sweep.
func take_hit(hit: HitInfo) -> void:
	if health != null and health.is_dead():
		return

	if blocker != null and blocker.blocks(hit):
		if health != null:
			health.apply_damage(hit.damage * blocker.chip_damage_fraction)
		blocker.absorb(hit)
		hit_blocked.emit(hit)
		Events.impact.emit(_impact_point(), hit.damage, true, _is_player())
		return

	if health != null:
		health.apply_damage(hit.damage)
	hit_taken.emit(hit)
	Events.impact.emit(_impact_point(), hit.damage, false, _is_player())


## Where sparks should appear. An Area3D's origin sits at the body root, so
## emitting at global_position puts the impact at the victim's ankles; the
## capsule shape is offset up to the chest, which is what we actually want.
func _impact_point() -> Vector3:
	for child in get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			return shape.global_position
	return global_position


## Feedback is asymmetric on purpose: being hit should shake YOUR camera much
## harder than landing a hit does.
func _is_player() -> bool:
	return body != null and body.is_in_group("player")
