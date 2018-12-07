local camera = require "orthographic.camera"

if sys.get_config("script.shared_state") ~= "1" then
	error("ERROR - camera - 'shared_state' setting in game.project must be enabled for camera to work.")
end	

local M = {}

local IDENTITY = vmath.matrix4()

local SET_VIEW_PROJECTION = hash("set_view_projection")
local SET_CAMERA_OFFSET = hash("set_camera_offset")

local world_view = vmath.matrix4()
local world_projection = vmath.matrix4()
local screen_view = vmath.matrix4()
local camera_offset = nil
local window_width = nil
local window_height = nil


function M.init()
end


function M.update()
	local current_window_width = render.get_window_width()
	local current_window_height = render.get_window_height()
	if window_width ~= current_window_width or window_height ~= current_window_height then
		window_width = current_window_width
		window_height = current_window_height
		camera.set_window_size(current_window_width, current_window_height)
	end
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


function M.screen_view()
	return IDENTITY
end

function M.screen_projection()
	local current_window_width = render.get_window_width()
	local current_window_height = render.get_window_height()
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
	return vmath.matrix4_orthographic(left, right, bottom, top, -1, 1)
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
	end
end

return M