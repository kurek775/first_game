# Bakes the island navigation mesh and writes it back to disk.
#
#   godot --headless --script tools/bake_navmesh.gd
#
# Run it whenever level collision changes. Baking at startup instead would work
# but costs a second of load every run and hides geometry mistakes until then;
# baking to a committed resource means a bad navmesh shows up in a diff.
extends SceneTree

const SCENE := "res://scenes/main.tscn"
const OUT := "res://resources/navigation/island_navmesh.tres"


func _init() -> void:
	var scene: Node = load(SCENE).instantiate()
	root.add_child(scene)

	# Static colliders are only registered with the physics server once the
	# tree has ticked, and the bake reads them from there.
	await physics_frame
	await physics_frame

	var region := scene.find_child("Navigation", true, false) as NavigationRegion3D
	if region == null:
		push_error("bake: no NavigationRegion3D named 'Navigation' in %s" % SCENE)
		quit(1)
		return

	var mesh := region.navigation_mesh
	if mesh == null:
		push_error("bake: region has no NavigationMesh assigned")
		quit(1)
		return

	print("baking from static colliders (mask %d)..." % mesh.geometry_collision_mask)
	# on_thread = false: we want to block here, not race the quit() below.
	region.bake_navigation_mesh(false)

	while region.is_baking():
		await physics_frame

	var polys := mesh.get_polygon_count()
	var verts := mesh.get_vertices().size()
	if polys == 0:
		push_error("bake: produced 0 polygons — is the world under the Navigation node?")
		quit(1)
		return

	mesh.take_over_path(OUT)
	var err := ResourceSaver.save(mesh, OUT)
	if err != OK:
		push_error("bake: could not save %s (error %d)" % [OUT, err])
		quit(1)
		return

	print("baked %d polygons, %d vertices -> %s" % [polys, verts, OUT])
	quit(0)
