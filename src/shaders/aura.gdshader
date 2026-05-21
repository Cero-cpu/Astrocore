shader_type canvas_item;
uniform vec4 aura_color : source_color = vec4(1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Drop Shadow
	vec4 shadow_tex = texture(TEXTURE, UV - vec2(3.0 * TEXTURE_PIXEL_SIZE.x, 3.0 * TEXTURE_PIXEL_SIZE.y));
	vec4 shadow = vec4(0.0, 0.0, 0.0, shadow_tex.a * 0.4);
	
	// Aura pequeña (grosor de 2 pixeles)
	float outline = texture(TEXTURE, UV + vec2(-TEXTURE_PIXEL_SIZE.x*2.0, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x*2.0, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, -TEXTURE_PIXEL_SIZE.y*2.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y*2.0)).a;
	outline = min(outline, 1.0);
	
	vec4 aura = vec4(aura_color.rgb, outline * 0.5);
	
	vec4 final_color = mix(shadow, aura, aura.a);
	final_color = mix(final_color, tex, tex.a);
	COLOR = final_color;
}
