--- Camera module to use in combination with the camera.go or camera.script

local M = {}


M.SHAKE_BOTH = hash("both")
M.SHAKE_HORIZONTAL = hash("horizontal")
M.SHAKE_VERTICAL = hash("vertical")


local DISPLAY_WIDTH = tonumber(sys.get_config("display.width"))
local DISPLAY_HEIGHT = tonumber(sys.get_config("display.height"))
local window_width = DISPLAY_WIDTH
local window_height = DISPLAY_HEIGHT

local OFFSET = vmath.vector3(DISPLAY_WIDTH / 2, DISPLAY_HEIGHT / 2, 0)

local app = require "ludobits.m.app"
app.window.add_listener(function(self, event, data)
	if event == window.WINDOW_EVENT_RESIZED then
		window_width = data.width
		window_height = data.height
	end
end)

local cameras = {}

--- projection providers (projectors)
-- a mapping of id to function to calculate and return a projection matrix
local projectors = {}

-- the default projector from the default render script
-- will stretch content
projectors[hash("DEFAULT")] = function(camera_id, near_z, far_z)
	return vmath.matrix4_orthographic(0, DISPLAY_WIDTH, 0, DISPLAY_HEIGHT, near_z, far_z)
end

-- fixed aspect ratio projector
projectors[hash("FIXED")] = function(camera_id, near_z, far_z)
	local zoom_factor = math.min(window_width / DISPLAY_WIDTH, window_height / DISPLAY_HEIGHT)
	local projected_width = window_width / zoom_factor
	local projected_height = window_height / zoom_factor
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

--- Add a custom projector
-- @param projector_id Unique id of the projector (hash)
-- @param projector_fn The function to call when the projection matrix needs to be calculated
-- The function will receive near_z and far_z as arguments
function M.add_projector(projector_id, projector_fn)
	orthographic_projectors[projector_id] = projector_fn
end


local function calculate_projection(camera_id)
	local url = msg.url(nil, camera_id, "script")
	local projector_id = go.get(url, "projection")
	local near_z = go.get(url, "near_z")
	local far_z = go.get(url, "far_z")
	local projector_fn = projectors[projector_id] or projectors[hash("DEFAULT")]
	return projector_fn(camera_id, near_z, far_z)
end

local function calculate_view(camera_id, offset)
	local rot = go.get_world_rotation(camera_id)
	local pos = go.get_world_position(camera_id) - vmath.rotate(rot, OFFSET)
	if offset then
		pos = pos + offset
	end

	local look_at = pos + vmath.rotate(rot, vmath.vector3(0, 0, -1.0))
	local up = vmath.rotate(rot, vmath.vector3(0, 1.0, 0))
	local view = vmath.matrix4_look_at(pos, look_at, up)
	return view
end


--- Initialize a camera
-- Note: This is called automatically from the init() function of the camera.script
-- @param camera_id
function M.init(camera_id)
	cameras[camera_id] = {}
end


--- Finalize a camera
-- Note: This is called automatically from the final() function of the camera.script
-- @param camera_id
function M.final(camera_id)
	cameras[camera_id] = nil
end


--- Update a camera
-- When calling this function a number of things happen:
-- * Follow target game object (if any)
-- * Shake the camera (if enabled)
-- * Recalculate the view and projection matrix
--
-- Note: This is called automatically from the final() function of the camera.script
-- @param camera_id
-- @param dt
function M.update(camera_id, dt)
	local camera = cameras[camera_id]
	if not camera then
		return
	end
	
	if camera.follow then
		local target_pos = go.get_position(camera.follow.target)
		local camera_pos = go.get_position(camera_id)
		local new_pos
		if camera.deadzone then
			new_pos = vmath.vector3(camera_pos)
			local left_edge = camera_pos.x - camera.deadzone.left
			local right_edge = camera_pos.x + camera.deadzone.right
			local top_edge = camera_pos.y + camera.deadzone.top
			local bottom_edge = camera_pos.y - camera.deadzone.bottom
			if target_pos.x < left_edge then
				new_pos.x = new_pos.x - (left_edge - target_pos.x)
			elseif target_pos.x > right_edge then
				new_pos.x = new_pos.x + (target_pos.x - right_edge)
			end
			if target_pos.y > top_edge then
				new_pos.y = new_pos.y + (target_pos.y - top_edge)
			elseif target_pos.y < bottom_edge then
				new_pos.y = new_pos.y - (bottom_edge - target_pos.y)
			end
		else
			new_pos = target_pos
		end
		if camera.follow.lerp then
			go.set_position(vmath.lerp(camera.follow.lerp or 0.1, camera_pos, new_pos), camera_id)
		else
			go.set_position(new_pos, camera_id)
		end
	end
	
	if camera.shake then
		camera.shake.duration = camera.shake.duration - dt
		if camera.shake.duration < 0 then
			camera.shake.cb()
			camera.shake = nil
			return
		end
		if camera.shake.horizontal then
			camera.shake.offset.x = (DISPLAY_WIDTH * camera.shake.intensity) * (math.random() - 0.5)
		end
		if camera.shake.vertical then
			camera.shake.offset.y = (DISPLAY_WIDTH * camera.shake.intensity) * (math.random() - 0.5)
		end
	end
	
	camera.view = calculate_view(camera_id, camera.shake and camera.shake.offset)	
	camera.projection = calculate_projection(camera_id)	
end


--- Follow a game object
-- @param camera_id
-- @param target The game object to follow
-- @param lerp Optional lerp to smoothly move the camera towards the target
function M.follow(camera_id, target, lerp)
	cameras[camera_id].follow = { target = target, lerp = lerp }
end


--- Unfollow a game object
-- @param camera_id
function M.unfollow(camera_id)
	cameras[camera_id].follow = nil
end


function M.deadzone(camera_id, left, right, bottom, top)
	cameras[camera_id].deadzone = {
		left = left,
		right = right,
		bottom = bottom,
		top = top,
	}
end

--- Shake a camera
-- @param camera_id
-- @param intensity Intensity of the shake in percent of screen width. Optional, default: 0.05.
-- @param duration Duration of the shake. Optional, default: 0.5s.
-- @param direction both|horizontal|vertical. Optional, default: both
-- @param cb Function to call when shake has completed. Optional
function M.shake(camera_id, intensity, duration, direction, cb)
	cameras[camera_id].shake = {
		intensity = intensity or 0.05,
		duration = duration or 0.5,
		horizontal = direction ~= M.SHAKE_VERTICAL or false,
		vertical = direction ~= M.SHAKE_HORIZONTAL or false,
		offset = vmath.vector3(0),
		cb = cb,
	}
end


--- Get the projection matrix for a camera
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
-- @return Projection matrix
function M.get_projection(camera_id)
	return cameras[camera_id].projection
end


--- Get the view matrix for a specific camera, based on the camera position
-- and rotation
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
-- @return View matrix
function M.get_view(camera_id)
	return cameras[camera_id].view
end


--- Send the view and projection matrix for a camera to the render script
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
function M.send_view_projection(camera_id)
	local view = cameras[camera_id].view or vmath.matrix4()
	local projection = cameras[camera_id].projection or vmath.matrix4()
	msg.post("@render:", "set_view_projection", { id = camera_id, view = view, projection = projection })
end


--- Convert screen coordinates to world coordinates based
-- on a specific camera's view and projection
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
-- @param x
-- @param y
-- @param z
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.screen_to_world(camera_id, x, y, z)
	local v3 = vmath.vector3(x, y, 0)
	local view = cameras[camera_id].view or vmath.matrix4()
	local projection = cameras[camera_id].projection or vmath.matrix4()

	x = 2 * x / DISPLAY_WIDTH - 1
	y = 2 * y / DISPLAY_HEIGHT - 1
	local inv = vmath.inv(projection * view)
	local v4 = inv * vmath.vector4(x, y, 0, 1)
	return vmath.vector3(v4.x, v4.y, z)
end


return M
