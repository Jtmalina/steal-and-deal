shader_type sky;
// ============================================================
//  The sky over the city: a sun that actually crosses it, a moon
//  and stars after dark, clouds drifting over the top and lit by
//  whichever of the two is up, and the orange glow of a city that
//  never quite goes dark sitting on the horizon at night.
//
//  DayNight works out where everything is and feeds it in; the
//  shader only has to paint it.
// ============================================================

uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);    // towards the sun
uniform vec3 moon_dir = vec3(0.0, -0.7, -0.7);
uniform float day : hint_range(0.0, 1.0) = 1.0;     // how lit the sky is
uniform float dusk : hint_range(0.0, 1.0) = 0.0;    // how much sunset is in it
uniform float night : hint_range(0.0, 1.0) = 0.0;   // stars and city glow
uniform float cover : hint_range(0.0, 1.0) = 0.6;  // how much cloud
uniform float drift = 0.0;                          // how far the clouds have blown
uniform float star_turn = 0.0;                      // the stars wheel over the night

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = turn * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec3 sky_colour(vec3 dir) {
	float up = max(dir.y, 0.0);
	vec3 day_top = lin(vec3(0.26, 0.50, 0.82));
	vec3 day_low = lin(vec3(0.70, 0.80, 0.90));
	vec3 night_top = lin(vec3(0.010, 0.016, 0.045));
	vec3 night_low = lin(vec3(0.05, 0.06, 0.10));

	float grade = pow(1.0 - up, 3.0);
	vec3 col = mix(mix(night_top, day_top, day), mix(night_low, day_low, day), grade);

	// sunset: warm along the horizon, hottest on the sun's side
	float toward = max(dot(normalize(vec2(dir.x, dir.z) + 1e-4),
		normalize(vec2(sun_dir.x, sun_dir.z) + 1e-4)), 0.0);
	vec3 burn = mix(lin(vec3(0.85, 0.34, 0.30)), lin(vec3(1.0, 0.58, 0.22)), toward);
	col = mix(col, burn, dusk * pow(1.0 - up, 5.0) * (0.45 + 0.55 * toward));

	// the city lighting the underside of the night
	col += lin(vec3(0.30, 0.17, 0.08)) * night * exp(-up * 9.0) * 0.8;
	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = sky_colour(dir);

	if (dir.y < 0.0) {
		// under the horizon is haze over ground the world never quite covers:
		// the horizon carried on down, dimming a little, so the edge of the map
		// fades out instead of stopping at a dark line
		vec3 haze = sky_colour(normalize(vec3(dir.x, 0.0, dir.z) + 1e-4));
		COLOR = haze * mix(1.0, 0.72, clamp(-dir.y * 3.0, 0.0, 1.0));
	} else if (AT_CUBEMAP_PASS) {
		// what lights and reflects the world does not need the detail
		COLOR = col;
	} else {
		// --- stars, turning slowly about the pole ---
		if (night > 0.01) {
			float c = cos(star_turn);
			float s = sin(star_turn);
			vec3 sd = vec3(c * dir.x - s * dir.y, s * dir.x + c * dir.y, dir.z);
			vec3 cell = floor(sd * 170.0);
			float h = hash3(cell);
			if (h > 0.972) {
				vec3 centre = (cell + 0.5 + (vec3(hash3(cell + 7.1), hash3(cell + 3.3),
					hash3(cell + 5.9)) - 0.5) * 0.6) / 170.0;
				float d = length(sd - centre) * 170.0;
				float size = mix(0.2, 0.42, pow((h - 0.972) / 0.028, 3.0));
				float twinkle = 0.65 + 0.35 * sin(TIME * (2.0 + h * 9.0) + h * 80.0);
				float star = smoothstep(size, 0.0, d) * twinkle;
				vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.85, 0.7), hash3(cell + 1.3));
				// the city's glow washes out the ones low down
				col += tint * star * star * night * 7.0 * smoothstep(0.02, 0.25, dir.y);
			}
		}

		// --- the moon ---
		float md = dot(dir, normalize(moon_dir));
		float disc = smoothstep(0.99988, 0.99992, md);
		if (disc > 0.0) {
			vec3 m = normalize(moon_dir);
			vec3 side = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
			vec3 top = cross(side, m);
			vec2 face = vec2(dot(dir, side), dot(dir, top)) * 90.0;
			float mare = fbm(face * 1.8 + 3.0);
			vec3 moon = lin(vec3(0.95, 0.94, 0.88)) * (0.72 + 0.4 * mare);
			col = mix(col, moon * 1.6, disc * (1.0 - day * 0.75));
		}
		col += lin(vec3(0.55, 0.62, 0.8)) * pow(max(md, 0.0), 900.0) * 0.25 * night;

		// --- the sun, and the glare round it ---
		float sd = dot(dir, normalize(sun_dir));
		vec3 sun_hot = mix(lin(vec3(1.0, 0.55, 0.25)), lin(vec3(1.0, 0.96, 0.88)), day);
		col += sun_hot * smoothstep(0.99955, 0.99975, sd) * 14.0 * (1.0 - night);
		col += sun_hot * pow(max(sd, 0.0), 600.0) * 1.8 * (1.0 - night);
		col += sun_hot * pow(max(sd, 0.0), 12.0) * (0.12 + dusk * 0.35) * (1.0 - night);

		// --- clouds on a flat layer overhead ---
		vec2 at = dir.xz / (dir.y + 0.09);
		vec2 uv = at * 0.9 + vec2(drift, drift * 0.37);
		float n = fbm(uv);
		float n2 = fbm(uv * 2.7 - vec2(drift * 0.6, 0.0) + 11.0);
		float shape = n * 0.75 + n2 * 0.25;
		float edge = mix(0.64, 0.36, cover);
		float cloud = smoothstep(edge, edge + 0.22, shape);
		// thin them into the distance so the horizon is not a wall
		cloud *= smoothstep(0.0, 0.12, dir.y);
		if (cloud > 0.001) {
			// thicker middles are darker underneath
			float thick = smoothstep(edge, edge + 0.45, shape);
			vec3 day_cloud = mix(lin(vec3(0.98, 0.98, 1.0)), lin(vec3(0.58, 0.61, 0.68)), thick);
			vec3 dusk_cloud = mix(lin(vec3(1.0, 0.62, 0.42)), lin(vec3(0.45, 0.30, 0.34)), thick);
			vec3 night_cloud = mix(lin(vec3(0.16, 0.14, 0.15)), lin(vec3(0.05, 0.05, 0.07)), thick);
			vec3 lit = mix(night_cloud, day_cloud, day);
			lit = mix(lit, dusk_cloud, dusk * 0.8);
			// a silver lining where the sun or moon sits behind
			float behind = pow(max(sd, 0.0), 8.0) * (1.0 - night)
				+ pow(max(md, 0.0), 20.0) * night * 0.5;
			lit += sun_hot * behind * (1.0 - thick) * 0.9;
			// and the city lighting them from below at night
			lit += lin(vec3(0.25, 0.14, 0.07)) * night * (1.0 - thick * 0.5) * 0.6;
			col = mix(col, lit, cloud * 0.92);
		}
		COLOR = col;
	}
}
