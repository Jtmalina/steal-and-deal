shader_type spatial;
// ============================================================
//  The outside of a building: a grid of windows on every wall,
//  a storey apart, centred on the face so the ends come out even
//  whatever the width. Drawn on the same unit cube as everything
//  else -- the box's scale says how big each face is in metres,
//  so a tall block gets more floors rather than taller windows.
//
//  After dark some of the windows come on. Which ones is a hash of
//  the window, so it is the same office light every night, and
//  `city_night` (DayNight sets it) says how dark it has got.
// ============================================================

global uniform float city_night;

uniform vec4 wall : source_color = vec4(0.55, 0.5, 0.45, 1.0);
uniform vec4 trim : source_color = vec4(0.3, 0.3, 0.32, 1.0);
uniform vec4 glass : source_color = vec4(0.16, 0.21, 0.28, 1.0);
uniform float storey = 3.2;       // floor to floor, metres
uniform float bay = 2.8;          // window to window, metres
uniform float win_w = 0.62;       // share of a bay that is glass
uniform float win_h = 0.56;       // share of a storey that is glass
uniform float first_floor = 0.0;  // no windows below this, metres up the wall
uniform float parapet = 0.9;      // nor in the top of the wall
uniform float lit_share = 0.45;   // how many come on at night
uniform float seed = 0.0;
uniform float windows_x = 1.0;    // 0 leaves the walls facing +/-X blank
uniform float windows_z = 1.0;    // and the ones facing +/-Z

varying vec3 obj;
// flat: the same for the whole face, where interpolating it drifts in the last
// bit -- enough to flip floor(width / bay) on a wall a whole number of bays
// wide, and the windows come out in a different pattern pixel by pixel
varying flat vec3 half_size;
varying vec3 n_obj;

float hash(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	half_size = s * 0.5;
	obj = VERTEX * s;
	n_obj = NORMAL;
}

void fragment() {
	vec3 col = wall.rgb;
	float rough = 0.88;
	float spec = 0.25;
	vec3 glow = vec3(0.0);
	float up = obj.y + half_size.y;

	if (abs(n_obj.y) > 0.5) {
		// roofs and undersides: tar and gravel
		col = trim.rgb * 0.8;
	} else {
		bool on_x = abs(n_obj.x) > 0.5;
		float along = on_x ? obj.z : obj.x;
		float width = on_x ? half_size.z * 2.0 : half_size.x * 2.0;
		float face_id = on_x ? sign(n_obj.x) * 1.0 : sign(n_obj.z) * 2.0;
		float wants = on_x ? windows_x : windows_z;
		float top = half_size.y * 2.0 - parapet;

		// grime gathers at the foot of a wall and under the parapet
		col *= mix(0.8, 1.0, smoothstep(0.0, 1.4, up));
		// a cap along the top
		if (up > half_size.y * 2.0 - 0.35) {
			col = trim.rgb;
		}

		float n = floor(width / bay + 1e-3);
		float floors = floor(max(top - first_floor, 0.0) / storey + 1e-3);
		float u = along + n * bay * 0.5;
		float v = up - first_floor;
		if (wants > 0.5 && n >= 1.0 && floors >= 1.0 && u > 0.0 && u < n * bay
				&& v > 0.0 && v < floors * storey) {
			vec2 cell = vec2(floor(u / bay), floor(v / storey));
			vec2 f = vec2(fract(u / bay), fract(v / storey));
			vec2 d = abs(f - vec2(0.5, 0.5));
			vec2 hw = vec2(win_w, win_h) * 0.5;
			// a band between floors, which is most of what reads as "storeys"
			if (f.y < 0.06) {
				col = mix(col, trim.rgb, 0.55);
			}
			if (d.x < hw.x && d.y < hw.y) {
				float h = hash(cell + vec2(seed * 7.13 + face_id * 19.7, seed * 3.1));
				// sky in the top of the pane, the room behind it lower down
				vec3 pane = mix(glass.rgb * 0.7, glass.rgb * 1.5 + vec3(0.05, 0.07, 0.1),
					smoothstep(-hw.y, hw.y, f.y - 0.5));
				// some have the blinds down
				if (h < 0.18) {
					pane = mix(pane, vec3(0.62, 0.58, 0.5), 0.55);
				}
				col = pane;
				rough = 0.12;
				spec = 0.7;
				// a glazing bar down the middle of the wider ones
				if (bay * win_w > 1.4 && abs(f.x - 0.5) < 0.015 / win_w) {
					col = trim.rgb;
					rough = 0.8;
				}
				// and the lights, some warm, a few the blue of a screen
				float on = step(1.0 - lit_share, fract(h * 7.31)) * city_night;
				vec3 lamp = mix(vec3(1.0, 0.72, 0.38), vec3(1.0, 0.86, 0.62), hash(cell + 3.7));
				if (fract(h * 13.7) > 0.85) {
					lamp = vec3(0.55, 0.7, 1.0);
				}
				glow = lamp * on * (0.9 + 0.8 * fract(h * 5.3));
				col = mix(col, lamp * 0.6, on * 0.6);
			} else if (d.x < hw.x + 0.04 && d.y < hw.y + 0.05) {
				// the frame and the sill round each one
				col = mix(col, trim.rgb, 0.8);
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = glow;
}
