/*
 * WiVRn VR streaming
 * Copyright (C) 2026  devon-fitzp <devonmf23@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
#version 450

// Clears the stream inside a box so that passthrough is visible.
// Only back faces are drawn, so each pixel covered by the box is drawn exactly once,
// including when the eye is inside the box.

layout(push_constant) uniform pc
{
	mat4 mvp;         // unit cube [-1, 1]^3 to clip space
	vec4 eye;         // xyz: eye position in unit cube coordinates
	vec4 half_extent; // xyz: box half size in metres, w: feather width in metres
};

#ifdef VERT_SHADER

layout(location = 0) in vec3 vPosition;

layout(location = 0) out vec3 outPosition;

void main()
{
	gl_Position = mvp * vec4(vPosition, 1.0);
	outPosition = vPosition;
}
#endif

#ifdef FRAG_SHADER

layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec4 outColor;

void main()
{
	float a = 1;

	if (half_extent.w > 0 && any(greaterThan(abs(eye.xyz), vec3(1))))
	{
		// Find where the eye ray enters the box, it leaves it at inPosition
		vec3 dir = inPosition - eye.xyz;
		vec3 inv_dir = 1 / dir;
		vec3 t0 = (vec3(-1) - eye.xyz) * inv_dir;
		vec3 t1 = (vec3(1) - eye.xyz) * inv_dir;
		vec3 t_min = min(t0, t1);
		float t_enter = clamp(max(max(t_min.x, t_min.y), t_min.z), 0, 1);

		// Distance from the middle of the chord to the box surface
		vec3 mid = eye.xyz + dir * (t_enter + 1) * 0.5;
		vec3 depth = (1 - abs(mid)) * half_extent.xyz;
		a = smoothstep(0, half_extent.w, min(min(depth.x, depth.y), depth.z));
	}

	// blending is dst * (1 - src_alpha)
	outColor = vec4(0, 0, 0, a);
}

#endif
