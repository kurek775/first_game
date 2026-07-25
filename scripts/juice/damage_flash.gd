## DamageFlash — red vignette pulse when the raider is hit.
##
## Alpha accumulates per hit and fades, so a flurry reads as worse than a single
## blow instead of every hit looking identical. Blocked hits get a flat, smaller
## pulse: you want to feel that you took it on the shield, not that you are dying.
extends ColorRect

@export var hit_color := Color(0.72, 0.06, 0.06, 1.0)
@export_range(0.0, 1.0, 0.01) var max_alpha := 0.5
@export_range(0.1, 10.0, 0.1) var fade_speed := 1.9
@export_range(0.0, 0.5, 0.01) var blocked_alpha := 0.12

var _alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = hit_color
	color.a = 0.0
	Events.impact.connect(_on_impact)


func _process(delta: float) -> void:
	if _alpha <= 0.0:
		return
	_alpha = maxf(0.0, _alpha - fade_speed * delta)
	color.a = _alpha


func _on_impact(_where: Vector3, damage: float, blocked: bool, on_player: bool) -> void:
	if not on_player:
		return
	var added := blocked_alpha if blocked else 0.028 * damage
	_alpha = minf(max_alpha, _alpha + added)
	color.a = _alpha
