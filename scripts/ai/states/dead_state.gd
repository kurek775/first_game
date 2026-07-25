## Dead — terminal. Nothing transitions out of here.
##
## Stops the corpse soaking up further hits (and further knockback), which
## otherwise lets you keep batting a dead body across the courtyard.
extends State

## Degrees to tip the mesh over. Stands in for a death animation.
@export var topple_degrees := 84.0


func enter() -> void:
	actor.stop()
	actor.attack.cancel()

	# Stop being a valid target: hitboxes find hurtboxes by monitorable.
	actor.hurtbox.monitorable = false
	# Stop being something the player collides with while running past.
	actor.set_collision_layer_value(3, false)

	actor.perception.set_physics_process(false)
	Events.enemy_killed.emit(actor)
	actor.visual.rotation.z = deg_to_rad(topple_degrees)
