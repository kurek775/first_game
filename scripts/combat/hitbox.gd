## Hitbox — the dealing end of a blow.
##
## Inert until a swing switches it on, then reports every Hurtbox it overlaps,
## at most once per swing. Sits on no collision layer at all (nothing needs to
## detect a hitbox) and masks layer 4, "hurtbox".

class_name Hitbox
extends Area3D

signal hit_landed(hurtbox: Hurtbox, hit: HitInfo)

## The body swinging this. Its own hurtbox is skipped.
@export var source: Node3D
@export var damage := 25.0
## Metres/second of push applied to whatever gets hit.
@export var knockback := 9.0

var _active := false
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	# Off until a swing needs it, so the physics server does no overlap work
	# during the 90% of the time nobody is attacking.
	monitoring = false
	area_entered.connect(_on_area_entered)


func is_active() -> bool:
	return _active


func activate() -> void:
	_already_hit.clear()
	_active = true
	monitoring = true
	_sweep_existing_overlaps()


func deactivate() -> void:
	_active = false
	monitoring = false


## Turning `monitoring` on does not retroactively fire area_entered for bodies
## that were ALREADY inside the box. Standing chest-to-chest with an enemy and
## swinging would miss entirely. So sweep the current overlaps once, one physics
## frame later (the server needs a tick before get_overlapping_areas is valid).
## _already_hit makes this safe against double-counting with area_entered.
func _sweep_existing_overlaps() -> void:
	await get_tree().physics_frame
	if not _active:
		return
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area3D) -> void:
	if _active:
		_try_hit(area)


func _try_hit(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _already_hit:
		return
	# Never hit yourself.
	if source != null and hurtbox.body == source:
		return

	_already_hit.append(hurtbox)

	# Origin is the hitbox, not the attacker's centre — knockback should push
	# away from where the blow connected.
	var hit := HitInfo.create(damage, knockback, source, global_position)
	hurtbox.take_hit(hit)
	hit_landed.emit(hurtbox, hit)
