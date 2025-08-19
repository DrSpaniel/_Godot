shader_type canvas_item;
uniform vec3 replacement_color: source_color;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec3 color_without_green = COLOR.rgb * vec3(1, 0, 0);
	float amount_of_red_and_blue = length(color_without_green);
	float red_and_blue_mask = step(0.25, amount_of_red_and_blue);
	vec3 retained_color = COLOR.rgb * red_and_blue_mask;
	float green_mask = (1.0 - red_and_blue_mask) * COLOR.g;
	vec3 masked_replacement_color = replacement_color * green_mask;
	vec3 final_color = retained_color + masked_replacement_color;
	COLOR.rgb = final_color;
	
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
