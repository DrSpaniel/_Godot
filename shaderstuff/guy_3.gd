extends Sprite2D


func _on_color_picker_color_changed(color: Color) -> void:
	material.set_shader_parameter("replacement_color", color)
	pass # Replace with function body.
