// NOTE: Shader automatically converted from Godot Engine 4.2.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,unshaded,specular_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform sampler2D heightmapA;
uniform sampler2D heightmapB;
uniform sampler2D heightmapC;

uniform sampler2D grass_texture;
uniform sampler2D dirt_texture;

void vertex() {
	//UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	POSITION = vec4(float((VERTEX_ID << 1) & 2)-1.0, float(VERTEX_ID & 2)-1.0, 0, 1);
	//UV = POSITION.xy;
	
}


float sphere_distance(vec3 pos, vec4 sphere) {
    return length(pos-sphere.xyz) - sphere.w;
}

vec3 sphere_normal(vec3 pos, vec4 sphere) {
	return normalize(pos-sphere.xyz);
}

float sphere_distance_with_displacement(vec3 pos, vec4 sphere, float freq, float intensity) {
	float displacement = sin(freq * pos.x) * sin(freq * pos.y) * sin(freq * pos.z) * intensity;
	return sphere_distance(pos, sphere) + displacement;
}

float blend(float a, float b, float blendRate) {
	return (a * (1.0 - blendRate)) + (b * blendRate);
}

float heightmap_distance(vec3 pos) {
	float heightA = texture(heightmapA, pos.xz / 32.0).x;
	float heightB = texture(heightmapB, pos.xz / 32.0).x;
	float height = (heightA * 2.0);
	// float height = blend(heightA, heightB, 0.1);
	// float height = (heightA * ) + (heightB * 0.1);
	//float height = heightB;
	return pos.y - height;
}

vec3 heightmap_normal(vec3 pos) {
	float height = texture(heightmapA, pos.xz / 256.0).x * 5.0;

	vec3 right = vec3(-1.0, 0.0, 0.0);
	vec3 left = vec3(1.0, 0.0, 0.0);
	vec3 up = vec3(0.0, 0.0, -1.0);
	vec3 down = vec3(0.0, 0.0, 1.0);

	left.y = texture(heightmapA, (pos.xz - vec2(left.x, left.z)) / 256.0).x * 5.0;
	right.y = texture(heightmapA, (pos.xz - vec2(right.x, right.z)) / 256.0).x * 5.0;
	up.y = texture(heightmapA, (pos.xz - vec2(up.x, up.z)) / 256.0).x * 5.0;
	down.y = texture(heightmapA, (pos.xz - vec2(down.x, down.z)) / 256.0).x * 5.0;

	vec3 normalVector = normalize(cross(right - left, up - down));

	return normalVector;
	
}

float easeInSine(float x) {
  return 1.0 - cos((x * PI) / 2.0);

}

float eastOutSine(float x) {
	return sin((x * PI) / 2.0);
}

float easeInOutSine(float x) {
	return -(cos(PI * x) - 1.0) / 2.0;
}

vec3 normal_sdf(vec3 pos) {
	vec3 normal = vec3(0.0);
	float dist = 1.0;
	float dist_temp = sphere_distance_with_displacement(pos, vec4(0,10.0,0,1.0), 5.0, (easeInOutSine(abs(sin(TIME*0.75))) * 0.16) + 0.1);
	if(dist_temp < dist) {
		dist = dist_temp;
		normal = sphere_normal(pos, vec4(0,10.0,0,1.0));
	}
	
	dist_temp = min(dist, sphere_distance(pos, vec4(5,10.0,0,1.0)));
	if(dist_temp < dist) {
		dist = dist_temp;
		normal = sphere_normal(pos, vec4(5,10.0,0,1.0));
	}
	
	dist_temp = min(dist, sphere_distance(pos, vec4(-5,10.0,0,1.0)));
	if(dist_temp < dist) {
		dist = dist_temp;
		normal = sphere_normal(pos, vec4(-5,10.0,0,1.0));
	}

	dist_temp = min(dist, heightmap_distance(pos));
	if(dist_temp < dist) {
		dist = dist_temp;
		normal = heightmap_normal(pos);
	}

	return normal;
}

float AABB_distance(vec3 pos, vec3 a, vec3 b) {
	vec3 r_min = min(a, b);
	vec3 r_max = max(a, b);
	float dx = max(r_min.x - pos.x, max(0, pos.x - r_max.x));
	float dy = max(r_min.y - pos.y, max(0, pos.y - r_max.y));
	float dz = max(r_min.z - pos.z, max(0, pos.z - r_max.z));
	return sqrt((dx*dx) + (dy*dy) + (dz*dz));
}

float weird_thing_distance(vec3 pos) {
	float dist = sphere_distance_with_displacement(pos, vec4(0,10.0,0, 10.0), 2.0, (easeInOutSine(abs(sin(TIME*0.75))) * 0.45) + 0.2);
	dist = max(dist, -sphere_distance(pos, vec4(0,10.0,0,9.9)));
	return dist;
}

float distance_sdf(vec3 pos) {
	float dist = 4000.0;

	{	// Create Sphere
		float distSphere = AABB_distance(pos, vec3(-10, -10, -10), vec3(10, 1.5, 10));
		distSphere = min(distSphere, AABB_distance(pos, vec3(-10, 9.5, -10), vec3(10, 10, 10)));
		distSphere = max(distSphere, sphere_distance(pos, vec4(0,0.0,0,10.0)));
		distSphere = min(distSphere, sphere_distance_with_displacement(pos, vec4(0,0.0,0, 10.0), 2.0, (easeInOutSine(abs(sin(TIME*0.75))) * 0.45) + 0.2));
		distSphere = max(distSphere, -sphere_distance(pos, vec4(0,0.0,0,9.9)));
		dist = min(dist, distSphere);
	}

	{	// Create Terrain in Sphere
		float distTerrain = heightmap_distance(pos);
		distTerrain = max(distTerrain, sphere_distance(pos, vec4(0,0.0,0,10.0)));
		dist = min(dist, distTerrain);
	}

	{	// Create Pillar thing
		float distPillar = 4000.0;
		distPillar = min(distPillar, AABB_distance(pos, vec3(-1, 0, -1), vec3(1, 10, 1)));
		distPillar = max(distPillar, -sphere_distance(pos, vec4(0, 4, 0, 1.5)));
		distPillar = min(distPillar, sphere_distance(pos, vec4(0, 4, 0, 1.0)));
		dist = min(dist, distPillar);
	}

	return dist;
}

vec3 normal_sdf_test(vec3 pos) {
	float epsilon = 0.1; // arbitrary — should be smaller than any surface detail in your distance function, but not so small as to get lost in float precision
	float centerDistance = distance_sdf(pos);
	float xDistance = distance_sdf(pos + vec3(epsilon, 0, 0));
	float yDistance = distance_sdf(pos + vec3(0, epsilon, 0));
	float zDistance = distance_sdf(pos + vec3(0, 0, epsilon));
	vec3 normal = (vec3(xDistance, yDistance, zDistance) - centerDistance) / epsilon;
	return normal;
}

vec4 raymarch(vec3 pos, vec3 dir, out bool found) {
	float d = 0.0;
	found = false;
	for (int i =0; i<1000; i++) {
		float step_dist = distance_sdf(pos + (dir * d));
		d += step_dist;
		if (step_dist < 0.001) {
			found = true;
			break;
		}
	}
	return vec4(pos+(dir*d), d);
}

void fragment() {
	//vec2 base_uv = UV;
	//vec4 albedo_tex = texture(texture_albedo,base_uv);
	//ALBEDO = albedo.rgb * albedo_tex.rgb;
	//float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	//METALLIC = metallic_tex * metallic;
	//vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	//float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	//ROUGHNESS = roughness_tex * roughness;
	//SPECULAR = specular;
	//
	vec3 pos = CAMERA_POSITION_WORLD;
	vec2 fd = (FRAGCOORD.xy - 0.5*VIEWPORT_SIZE); // VIEWPORT_SIZE -> 1600,900
	vec3 dir = normalize(vec3(fd.x, -fd.y, -VIEWPORT_SIZE.y));


	// vec2 fd = (SCREEN_UV - 0.5);
	// vec3 dir = normalize(vec3(fd.x * (16.0/9.0), -fd.y, -1.0));
	
	dir = (INV_VIEW_MATRIX * vec4(dir, 0.0)).xyz;
	//vec3 dir = normalize(-CAMERA_DIRECTION_WORLD);
	bool found;
	vec4 m = raymarch(pos, normalize(dir), found);
	//vec3 dir = normalize(vec3(pixel.xy - 0.5*resolution.xy, resolution.y));
	vec3 colorA = vec3(256,42,0)/256.0;
	colorA = vec3(0,0,0);
	// colorA = texture(dirt_texture, m.xz / 2.0).rgb;
	vec3 colorB = vec3(.6, .4, 0.0);
	// colorB = texture(grass_texture, m.xz / 2.0).rgb;
	// ALBEDO = vec3(abs(sin(m.y * 5.0) * 0.5) + 0.5, 0.0, 0.0);
	float a = (abs(sin((m.y * 2.0)+(texture(heightmapC, m.xz / 4.0).x * 1.0))) * 0.5);
	// ALBEDO = (colorA * a) + (colorB * (1.0-a));
	ALBEDO = mix(colorA, colorB, a);
	// ALBEDO = colorA;
	// DEPTH = 0.0;

	// ALBEDO = vec3(1.0,0,0);
	// ALBEDO = vec3(m.w/4000.0, 0.0, 0.0);
	
	DEPTH = found ? m.w/4000.0 : 1.0;
	// ALBEDO = vec3(DEPTH,0,0);

	// ALBEDO = vec3(m.w/10000000.0);

	NORMAL_MAP = normal_sdf_test(m.xyz);
	// ALBEDO = NORMAL;
	//ALPHA = m.w;
	//ALBEDO = CAMERA_DIRECTION_WORLD
	
	//ALBEDO=vec3((FRAGCOORD.xy/VIEWPORT_SIZE).xy, 0.0);
}
