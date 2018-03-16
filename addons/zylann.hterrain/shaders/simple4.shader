shader_type spatial;

uniform sampler2D height_texture;
uniform sampler2D normal_texture;
uniform sampler2D color_texture : hint_albedo;
uniform sampler2D splat_texture;
uniform sampler2D mask_texture;
uniform vec2 heightmap_resolution;
uniform mat4 heightmap_inverse_transform;

uniform sampler2D detail_albedo_0 : hint_albedo;
uniform sampler2D detail_albedo_1 : hint_albedo;
uniform sampler2D detail_albedo_2 : hint_albedo;
uniform sampler2D detail_albedo_3 : hint_albedo;
uniform float detail_scale = 20.0;

uniform bool depth_blending = true;


vec3 unpack_normal(vec3 rgb) {
	return rgb * 2.0 - vec3(1.0);
}

float brightness(vec3 rgb) {
	// TODO Hey dude, you lazy
	return 0.33 * (rgb.r + rgb.g + rgb.b);
}

void vertex() {
	vec4 tv = heightmap_inverse_transform * WORLD_MATRIX * vec4(VERTEX, 1);
	vec2 uv = vec2(tv.x, tv.z) / heightmap_resolution;
	float h = texture(height_texture, uv).r;
	VERTEX.y = h;
	UV = uv;
	NORMAL = unpack_normal(texture(normal_texture, UV).rgb);
}

void fragment() {

	float mask = texture(mask_texture, UV).r;
	if(mask < 0.5)
		discard;

	vec3 n = unpack_normal(texture(normal_texture, UV).rgb);
	NORMAL = (INV_CAMERA_MATRIX * (WORLD_MATRIX * vec4(n, 0.0))).xyz;
	
	vec4 splat = texture(splat_texture, UV);

	// TODO Detail should only be rasterized on nearby chunks (needs proximity management to switch shaders)
	
	// TODO Should use local XZ
	vec2 detail_uv = UV * detail_scale;
	vec4 col0 = texture(detail_albedo_0, detail_uv);
	vec4 col1 = texture(detail_albedo_1, detail_uv);
	vec4 col2 = texture(detail_albedo_2, detail_uv);
	vec4 col3 = texture(detail_albedo_3, detail_uv);
	
	vec3 tint = texture(color_texture, UV).rgb;
		
	// TODO An #ifdef macro would be nice! Or move in a different shader, heh
	if (depth_blending) {
		
		float dh = 0.2;

		// TODO Keep improving multilayer blending, there are still some edge cases...
		// Mitigation workaround is used for now.
		// Maybe should be using actual bumpmaps to be sure
		
		vec4 h;
		//splat *= 1.4; // Mitigation #1: increase splat range over bump
		h.r = brightness(col0.rgb) + splat.r;
		h.g = brightness(col1.rgb) + splat.g;
		h.b = brightness(col2.rgb) + splat.b;
		h.a = brightness(col3.rgb) + splat.a;
		
		// Mitigation #2: nullify layers with near-zero splat
		float sc = 0.05;
		h *= smoothstep(0, sc, splat);
		
		vec4 d = h + dh;
		d.r -= max(h.g, max(h.b, h.a));
		d.g -= max(h.r, max(h.b, h.a));
		d.b -= max(h.g, max(h.r, h.a));
		d.a -= max(h.g, max(h.b, h.r));
		
		vec4 w = clamp(d, 0, 1);
		
    	ALBEDO = (w.r * col0.rgb + w.g * col1.rgb + w.b * col2.rgb + w.a * col3.rgb) / (w.r + w.g + w.b + w.a);
		
	} else {
		
		float w0 = splat.r;
		float w1 = splat.g;
		float w2 = splat.b;
		float w3 = splat.a;
		
    	ALBEDO = (w0 * col0.rgb + w1 * col1.rgb + w2 * col2.rgb + w3 * col3.rgb) / (w0 + w1 + w2 + w3);
	}
	
	//ALBEDO = splat.rgb;
}

