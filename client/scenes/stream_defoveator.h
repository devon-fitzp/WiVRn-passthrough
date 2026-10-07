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

#pragma once

#include "vk/allocation.h"
#include "wivrn_packets.h"
#include <glm/glm.hpp>
#include <vector>
#include <vulkan/vulkan_raii.hpp>
#include <openxr/openxr.h>

class stream_defoveator
{
	struct vertex;
	static const uint32_t view_count = 2;
	// Vertex buffer
	buffer_allocation buffer;
	size_t vertices_size = 0;

	vk::raii::Device & device;
	vk::raii::PhysicalDevice & physical_device;

	// Graphic pipeline
	vk::raii::RenderPass renderpass = nullptr;
	vk::raii::DescriptorPool ds_pool = nullptr;
	struct pipeline_t
	{
		vk::raii::DescriptorSetLayout descriptor_set_layout = nullptr;
		vk::DescriptorSet ds;
		vk::raii::PipelineLayout layout = nullptr;
		vk::raii::Pipeline pipeline = nullptr;
	};
	pipeline_t pipeline_rgb[view_count];
	pipeline_t pipeline_a[view_count];

	// Mixed reality cutouts
	buffer_allocation cube_buffer;
	vk::raii::PipelineLayout cutout_layout = nullptr;
	vk::raii::Pipeline cutout_pipeline = nullptr;

	// Destination images
	std::vector<vk::Image> output_images;
	std::vector<vk::raii::ImageView> output_image_views;
	std::vector<vk::raii::Framebuffer> framebuffers;
	vk::Extent2D output_extent;

	void ensure_vertices(size_t num_vertices);
	vertex * get_vertices(size_t view);

	pipeline_t & ensure_pipeline(size_t view, vk::Sampler rgb, vk::Sampler a);
	void ensure_cutout_pipeline();

public:
	struct input
	{
		vk::ImageView rgb;
		vk::Sampler sampler_rgb;
		vk::Rect2D rect_rgb;
		vk::ImageLayout layout_rgb;
		vk::ImageView a;
		vk::Sampler sampler_a;
		vk::Rect2D rect_a;
		vk::ImageLayout layout_a;
	};

	struct cutout
	{
		glm::mat4 mvp;         // unit cube [-1, 1]^3 to clip space
		glm::vec4 eye;         // eye position in unit cube coordinates
		glm::vec4 half_extent; // xyz: box half size in metres, w: feather width in metres
	};

	struct mixed_reality
	{
		std::array<float, 4> key_color{};             // rgb, w > 0 to enable chroma key
		std::array<float, 4> key_params{0, 0, 0, 1};  // threshold, smoothness, spill, opacity
		std::array<std::vector<cutout>, 2> cutouts{}; // per view
	};

	stream_defoveator(
	        vk::raii::Device & device,
	        vk::raii::PhysicalDevice & physical_device,
	        std::vector<vk::Image> output_images,
	        vk::Extent2D output_extent,
	        vk::Format format);

	stream_defoveator(const stream_defoveator &) = delete;

	void reset_pipelines();

	void defoveate(
	        vk::raii::CommandBuffer & command_buffer,
	        const std::array<wivrn::to_headset::foveation_parameter, 2> & foveation,
	        const std::array<input, 2> & inputs,
	        std::array<float, 4> scale,
	        std::array<float, 4> bias,
	        const mixed_reality & mr,
	        int destination);

	static XrExtent2Di defoveated_size(const wivrn::to_headset::foveation_parameter &);
};
