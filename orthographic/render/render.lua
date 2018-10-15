local camera = require "orthographic.camera"


local M = {}

local IDENTITY = vmath.matrix4()

local SET_VIEW_PROJECTION = hash("set_view_projection")
local SET_CAMERA_OFFSET = hash("set_camera_offset")

local DISPLAY_WIDTH = tonumber(sys.get_config("display.width"))
local DISPLAY_HEIGHT = tonumber(sys.get_config("display.height"))

local high_dpi = sys.get_config("display.high_dpi", "0") == "1"


function M.init(self)
	-- Check if 'shared_state' setting is on
	-- From https://github.com/rgrams/rendercam/blob/master/rendercam/rendercam.lua#L4-L7
	if sys.get_config("script.shared_state") ~= "1" then
		error("ERROR - camera - 'shared_state' setting in game.project must be enabled for camera to work.")
	end	

	self.world_view = vmath.matrix4()
	self.world_projection = vmath.matrix4()
	self.screen_view = vmath.matrix4()
	self.camera_offset = nil
	self.window_width = nil
	self.window_height = nil
end


function M.update(self, dt)
	local window_width = render.get_window_width()
	local window_height = render.get_window_height()
	if self.window_width ~= window_width or self.window_height ~= window_height then
		self.window_width = window_width
		self.window_height = window_height

		-- update window width/height for camera (used by the projections)
		if high_dpi then
			camera.set_window_size(window_width / 2, window_height /2)
		else
			camera.set_window_size(window_width, window_height)
		end
	end
end

function M.world_projection(self)
	return self.world_projection
end

function M.world_view(self)
	return self.world_view
end

function M.set_world_view_projection(self)
	render.set_view(M.world_view(self))
	render.set_projection(M.world_projection(self))
end

function M.screen_projection(self)
	local window_width = render.get_window_width()
	local window_height = render.get_window_height()
	local left, right, bottom, top
	if self.camera_offset then
		left = self.camera_offset.x
		right = left + window_width
		bottom = self.camera_offset.y
		top = bottom + window_height
	else
		left = 0
		right = window_width
		bottom = 0
		top = window_height
	end
	return vmath.matrix4_orthographic(left, right, bottom, top, -1, 1)
end

function M.set_screen_view_projection(self)
	render.set_view(IDENTITY)
	render.set_projection(M.screen_projection(self))
end


function M.on_message(self, message_id, message, sender)
	if message_id == SET_VIEW_PROJECTION then
		self.world_view = message.view
		self.world_projection = message.projection
	elseif message_id == SET_CAMERA_OFFSET then
		self.camera_offset = message.offset
	end
end

return M