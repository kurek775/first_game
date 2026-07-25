## ImpactBurst — a one-shot spark puff, spawned where a blow landed.
##
## Frees itself. The timer ignores time_scale, or a burst spawned during
## hit-stop would linger 16x too long and pile up.
extends GPUParticles3D


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.25, true, false, true).timeout
	queue_free()
