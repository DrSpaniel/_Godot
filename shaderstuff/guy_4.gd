extends Sprite2D




func _on_h_slider_value_changed(value: float) -> void:
	material.set_shader_parameter("amount", int(value))
	pass # Replace with function body.
