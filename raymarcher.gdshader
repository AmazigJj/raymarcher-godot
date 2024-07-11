// NOTE: Shader automatically converted from Godot Engine 4.2.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley/*unshaded*/,specular_disabled;
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
	POSITION = vec4(float((VERTEX_ID << 1) & 2)-1.0, float(VERTEX_ID & 2)-1.0, 0, 1);
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

float distance_heightmap(vec2 pos) {
	float heightA = texture(heightmapA, pos / 32.0).x;
	float heightB = texture(heightmapB, pos / 32.0).x;
	float height = (heightA * 8.0);
	// float height = blend(heightA, heightB, 0.1);
	// float height = (heightA) + (heightB);
	return height;
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
		// float distTerrain = pos.y - distance_heightmap(pos.xz);
		// distTerrain = max(distTerrain, sphere_distance(pos, vec4(0,0.0,0,10.0)));
		// dist = min(dist, terrain_distance);
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
	float centerDistance	= distance_sdf(pos);
	float xDistance			= distance_sdf(pos + vec3(epsilon, 0, 0));
	float yDistance			= distance_sdf(pos + vec3(0, epsilon, 0));
	float zDistance			= distance_sdf(pos + vec3(0, 0, epsilon));
	vec3 normal = (vec3(xDistance, yDistance, zDistance) - centerDistance) / epsilon;
	return normal;
}

vec3 normal_terrain(vec3 pos) {
	// float slopeX = dFdx(distance_heightmap(pos.xz));
	// float slopeZ = dFdy(distance_heightmap(pos.xz));
	// float slopeY = sqrt(1.0 - (slopeX*slopeX) - (slopeZ*slopeZ));
	// // Normal points in opposite sign as it slopes 
	// vec3 normal = vec3(-slopeX, slopeY, -slopeZ);

	vec2 coords = pos.xz;
	float unit = 1.0;
	float up		= distance_heightmap(coords + vec2( 0, -1) * unit);
	float down		= distance_heightmap(coords + vec2( 0,  1) * unit);
	float left		= distance_heightmap(coords + vec2(-1,  0) * unit);
	float right		= distance_heightmap(coords + vec2( 1,  0) * unit);

	vec3 xdiff = pos + vec3(right-left, 0.0, 0.0);
	vec3 ydiff = pos + vec3(0.0, 0.0, down-up);


	vec3 normal = normalize(cross(xdiff, ydiff));

	return normal;
}

bool raymarch(vec3 pos, vec3 dir, float terrain_distance, out float distance) {
	float d = 0.0;
	for (int i = 0; i < 100; i++) {
		float step_dist = distance_sdf(pos + (dir * d));
		d += step_dist;
		if (step_dist < 0.001) {
			distance = d;
			return true;
		}
	}
	return false;
}

const float minT = 0.1;
const float maxT = 300.0;

bool raymarch_terrain(vec3 origin, vec3 dir, out float ret_t) {
	float dt = 0.1;
	float lh = 0.0;
	float ly = 0.0;
	for (float t = minT; t < maxT; t+= dt) {
		vec3 sample_point = origin + dir * t;
		float terrain_height = distance_heightmap(sample_point.xz);
		float distance_to_terrain = sample_point.y - terrain_height;
		if (distance_to_terrain < 0.01) {
			ret_t = t - dt + dt * ((lh - ly) / (sample_point.y - ly - terrain_height + lh));
			return true;
		}
		lh = terrain_height;
		ly = sample_point.y;
		dt = t * 0.01; // step 1% of the cumulative distance travelled
	}
	return false;
}

vec3 color_terrain(vec3 pos) {
	vec3 colorA = vec3(25,105,6)/256.0;
	// colorA = texture(dirt_texture, m.xz / 2.0).rgb;
	vec3 colorB = vec3(.35, .2, 0.1);
	// colorB = texture(grass_texture, m.xz / 2.0).rgb;
	// ALBEDO = vec3(abs(sin(m.y * 5.0) * 0.5) + 0.5, 0.0, 0.0);
	float a = (abs(sin((pos.y * 2.0)+(texture(heightmapC, pos.xz / 4.0).x * 1.0))) * 0.5);
	// ALBEDO = (colorA * a) + (colorB * (1.0-a));
	return mix(colorA, colorB, a);
}

vec3 color_sdf(vec3 pos) {
	vec3 colorA = vec3(256,42,0)/256.0;
	colorA = vec3(0,0,0);
	// colorA = texture(dirt_texture, m.xz / 2.0).rgb;
	vec3 colorB = vec3(.6, .4, 0.0);
	// colorB = texture(grass_texture, m.xz / 2.0).rgb;
	// ALBEDO = vec3(abs(sin(m.y * 5.0) * 0.5) + 0.5, 0.0, 0.0);
	float a = (abs(sin((pos.y * 2.0)+(texture(heightmapC, pos.xz / 4.0).x * 1.0))) * 0.5);
	// ALBEDO = (colorA * a) + (colorB * (1.0-a));
	return mix(colorA, colorB, a);
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
	float terrain_distance = -1.0;
	bool found_terrain = raymarch_terrain(pos, normalize(dir), terrain_distance);
	vec3 terrain_position = pos + (dir * terrain_distance);

	float sdf_distance = -1.0;
	bool sdf_found = raymarch(pos, normalize(dir), terrain_distance, sdf_distance);
	vec3 sdf_position = vec3(pos + dir * sdf_distance);

	bool show_terrain = found_terrain && terrain_distance < sdf_distance;
	bool debug = false;
	if (show_terrain) {
		vec3 terrain_color = color_terrain(terrain_position);
		vec3 terrain_normal = (INV_VIEW_MATRIX * vec4(normal_terrain(terrain_position), 0.0)).xyz;
		ALBEDO = debug ? terrain_normal : terrain_color;
		DEPTH = terrain_distance / 300.0;
		NORMAL_MAP = terrain_normal;
	} else {
		vec3 sdf_color = color_sdf(sdf_position);
		vec3 sdf_normal = normal_sdf_test(sdf_position);
		ALBEDO = debug? sdf_normal : sdf_color;
		DEPTH = sdf_found ? sdf_distance/4000.0 : 1.0;
		NORMAL_MAP = sdf_normal;
	}

	//vec3 dir = normalize(vec3(pixel.xy - 0.5*resolution.xy, resolution.y));
	// ALBEDO = vec3(terrain_distance / 300.0, 0.0, 0.0);
	// DEPTH = 0.0;

	// ALBEDO = vec3(1.0,0,0);
	// ALBEDO = vec3(m.w/4000.0, 0.0, 0.0);
	
	// ALBEDO = vec3(DEPTH,0,0);

	// ALBEDO = vec3(m.w/10000000.0);

	// ALBEDO = NORMAL;
	//ALPHA = m.w;
	//ALBEDO = CAMERA_DIRECTION_WORLD
	
	//ALBEDO=vec3((FRAGCOORD.xy/VIEWPORT_SIZE).xy, 0.0);
}
