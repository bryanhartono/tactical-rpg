shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, blend_mix;

// Renders an outline around the opaque part of the sprite by sampling 4 cardinal
// neighbors at `outline_thickness` pixel distance. Pre-split single-direction PNGs
// (no atlas region) make this safe — neighbor samples don't bleed into other frames.

uniform sampler2D albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 4.0) = 1.0;
uniform vec2 sprite_pixel_size = vec2(64.0, 64.0);

void fragment() {
	vec4 c = texture(albedo, UV);
	if (c.a > 0.5) {
		ALBEDO = c.rgb;
		ALPHA = c.a;
	} else {
		vec2 px = vec2(outline_thickness) / sprite_pixel_size;
		float n = texture(albedo, UV + vec2( px.x, 0.0)).a
				+ texture(albedo, UV + vec2(-px.x, 0.0)).a
				+ texture(albedo, UV + vec2(0.0,  px.y)).a
				+ texture(albedo, UV + vec2(0.0, -px.y)).a;
		if (n > 0.0) {
			ALBEDO = outline_color.rgb;
			ALPHA = outline_color.a;
		} else {
			discard;
		}
	}
}
