/*
 * WiVRn VR streaming
 * Copyright (C) 2022  Guillaume Meunier <guillaume.meunier@centraliens.net>
 * Copyright (C) 2022  Patrick Nicolas <patricknicolas@laposte.net>
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

layout(push_constant) uniform pc
{
	ivec4 rgb_rect;
	ivec4 a_rect;
	vec4 scale;
	vec4 bias;
	vec4 key_color;  // rgb: chroma key colour, w: chroma key enabled
	vec4 key_params; // x: threshold, y: smoothness, z: spill, w: opacity
};

#ifdef VERT_SHADER

layout (location = 0) in vec2 vPosition;
layout (location = 1) in uvec2 vUV;

layout(location = 0) out vec4 outUV;

void main()
{
	gl_Position = vec4(vPosition, 0.0, 1.0);
	vec2 uv = vUV;
	outUV.xy = (uv + rgb_rect.xy) / rgb_rect.zw;
	outUV.zw = (uv + a_rect.xy) / a_rect.zw;
}
#endif

#ifdef FRAG_SHADER

layout(constant_id = 0) const int alpha = 1;
layout(constant_id = 1) const bool do_srgb = false;

layout(set = 0, binding = 0) uniform sampler2D rgb[alpha + 1];

layout(location = 0) in vec4 inUV;

layout(location = 0) out vec4 outColor;

float sRGB_to_linear(float x)
{
	if (x <= 0.04045)
		return x / 12.92;
	return pow((x + 0.055) / 1.055, 2.4);
}

vec4 sRGB_to_linear_rgba(vec4 x)
{
	return vec4(
	        sRGB_to_linear(x.r),
	        sRGB_to_linear(x.g),
	        sRGB_to_linear(x.b),
	        x.a);
}

vec2 chroma(vec3 c)
{
	// BT.709 CbCr
	return vec2(
	        dot(c, vec3(-0.1146, -0.3854, 0.5)),
	        dot(c, vec3(0.5, -0.4542, -0.0458)));
}

// returns the alpha of the pixel and removes the key colour spill
float chroma_key(inout vec3 c)
{
	float d = distance(chroma(c), chroma(key_color.rgb));
	float a = smoothstep(key_params.x, key_params.x + key_params.y, d);

	// clamp the dominant channel of the key colour to the average of the other two
	vec3 key = key_color.rgb;
	if (key.g >= key.r && key.g >= key.b)
		c.g = mix(c.g, min(c.g, 0.5 * (c.r + c.b)), key_params.z * (1 - a));
	else if (key.b >= key.r)
		c.b = mix(c.b, min(c.b, 0.5 * (c.r + c.g)), key_params.z * (1 - a));
	else
		c.r = mix(c.r, min(c.r, 0.5 * (c.g + c.b)), key_params.z * (1 - a));

	return a;
}

void main()
{
	if (alpha == 1)
	{
		// Avoid sampling between the eyes
		vec2 a = inUV.zw;
		float d = a.x - 0.5;
		if (abs(d) *a_rect.z < 1)
			a.x += (d > 0 ? 1 : -1)  / float(a_rect.z);
		outColor = vec4(texture(rgb[0], inUV.xy).rgb, texture(rgb[1], a).r);
	}
	else
	{
		outColor = vec4(texture(rgb[0], inUV.xy).rgb, 1);

		// the application did not provide alpha, compute it from the key colour
		if (key_color.w > 0)
			outColor.a = chroma_key(outColor.rgb);
	}

	if (do_srgb)
	{
		outColor = sRGB_to_linear_rgba(outColor);
	}

	// colour from the alpha stream is premultiplied
	if (alpha == 1 && outColor.a >= 0.02)
		outColor.rgb /= outColor.a;

	outColor.a *= key_params.w;

	if (outColor.a < 0.02)
	{
		outColor = vec4(0);
	}
	else
	{
		outColor = outColor * scale + bias;
		outColor.rgb *= outColor.a;
	}
}

#endif
