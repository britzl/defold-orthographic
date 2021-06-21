local camera = require "orthographic.camera"

if sys.get_config("script.shared_state") ~= "1" then
	error("ERROR - camera - 'shared_state' setting in game.project must be enabled for camera to work.")
end

local M = {}

local IDENTITY = vmath.matrix4()

local SET_VIEW_PROJECTION = hash("set_view_projection")
local SET_CAMERA_OFFSET = hash("set_camera_offset")
local SET_VIEWPORT = hash("set_viewport")

local world_view = vmath.matrix4()
local world_projection = vmath.matrix4()
local screen_view = vmath.matrix4()
local screen_projection = vmath.matrix4()
local camera_offset = nil
local world_viewport = vmath.vector4()

function M.init()
	world_viewport.x = 0
	world_viewport.y = 0
	world_viewport.z = render.get_window_width()
	world_viewport.w = render.get_window_height()
end

function M.world_projection()
	return world_projection
end

function M.world_view()
	return world_view
end

function M.set_world_view_projection()
	render.set_view(M.world_view())
	render.set_projection(M.world_projection())
end

function M.set_world_view_viewport()
	render.set_viewport(world_viewport.x, world_viewport.y, world_viewport.z, world_viewport.w)
end


function M.screen_view()
	return IDENTITY
end

function M.screen_projection()
	local current_window_width = render.get_window_width()
	local current_window_height = render.get_window_height()
	if current_window_width ~= 0 and current_window_height ~= 0 then
		local left, right, bottom, top
		if camera_offset then
			left = camera_offset.x
			right = left + current_window_width
			bottom = camera_offset.y
			top = bottom + current_window_height
		else
			left = 0
			right = current_window_width
			bottom = 0
			top = current_window_height
		end
		screen_projection = vmath.matrix4_orthographic(left, right, bottom, top, -1, 1)
	end
	return screen_projection
end

function M.set_screen_view_viewport()
	render.set_viewport(0, 0, render.get_window_width(), render.get_window_height())
end

function M.set_screen_view_projection()
	render.set_view(M.screen_view())
	render.set_projection(M.screen_projection())
end


function M.on_message(_, message_id, message)
	if message_id == SET_VIEW_PROJECTION then
		world_view = message.view
		world_projection = message.projection
	elseif message_id == SET_CAMERA_OFFSET then
		camera_offset = message.offset
	elseif message_id == SET_VIEWPORT then
		world_viewport = message.viewport
	end
end

return M
