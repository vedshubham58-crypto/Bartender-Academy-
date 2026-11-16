extends "res://tests/app_test.gd"
## Screenshots the POV hands while straining (are the arms clean, never crossing?).
## Run: godot --path . --rendering-method gl_compatibility --resolution 720x1280 res://tests/strain_shot.tscn -- /tmp/s/a --drinks=sidecar --count=1


func _between_steps() -> void:
	if main.cur.step.t == "strain":
		_strain_shots()


func _strain_shots() -> void:
	for k in 5:
		await _secs(0.18 if k == 0 else 0.2)
		await shot("strain_%d" % k)
