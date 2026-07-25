## HitInfo — everything one blow carries, passed from Hitbox to Hurtbox.
##
## RefCounted, not Resource: these are created and thrown away several times a
## second and never saved to disk, so they want the cheapest possible object.

class_name HitInfo
extends RefCounted

## Hit points to subtract before any blocking reduction.
var damage := 0.0
## Metres/second of push applied away from `origin`.
var knockback := 0.0
## The body that swung. Used so an attacker never hits its own hurtbox.
var source: Node3D = null
## Where the blow came from. Knockback direction and the blocker's frontal
## arc test are both measured from this, NOT from the attacker's current
## position — by the time the hit resolves they can differ.
var origin := Vector3.ZERO


static func create(p_damage: float, p_knockback: float, p_source: Node3D, p_origin: Vector3) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = p_damage
	hit.knockback = p_knockback
	hit.source = p_source
	hit.origin = p_origin
	return hit
