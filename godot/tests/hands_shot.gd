extends "res://tests/app_test.gd"
## Saves a frame every 0.12 s of play, to check the POV hands against glasses, tins,
## bottles and the ice well.
## Run: godot --path . --rendering-method gl_compatibility --resolution 720x1280 res://tests/hands_shot.tscn -- /tmp/h --drinks=margarita --count=1

var _t := 0.0
var _n := 0


func _process(delta: float) -> void:
	if main == null or not main.in_shift:
		return
	_t += delta
	if _t < 0.12:
		return
	_t = 0.0
	_n += 1
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2)
	img.save_jpg("%s/h_%04d.jpg" % [out, _n], 0.8)
