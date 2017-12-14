--- Camera module to use in combination with the camera.go or camera.script

local M = {}


M.SHAKE_BOTH = hash("both")
M.SHAKE_HORIZONTAL = hash("horizontal")
M.SHAKE_VERTICAL = hash("vertical")

M.PROJECTOR = {}
M.PROJECTOR.DEFAULT = hash("DEFAULT")
M.PROJECTOR.FIXED = hash("FIXED")
M.PROJECTOR.FIXED_NOZOOM = hash("FIXED_NOZOOM")
M.PROJECTOR.FIXED_ZOOM_2 = hash("FIXED_ZOOM_2")
M.PROJECTOR.FIXED_ZOOM_3 = hash("FIXED_ZOOM_3")
M.PROJECTOR.FIXED_ZOOM_4 = hash("FIXED_ZOOM_4")
M.PROJECTOR.FIXED_ZOOM_5 = hash("FIXED_ZOOM_5")
M.PROJECTOR.FIXED_ZOOM_6 = hash("FIXED_ZOOM_6")
M.PROJECTOR.FIXED_ZOOM_7 = hash("FIXED_ZOOM_7")
M.PROJECTOR.FIXED_ZOOM_8 = hash("FIXED_ZOOM_8")
M.PROJECTOR.FIXED_ZOOM_9 = hash("FIXED_ZOOM_9")
M.PROJECTOR.FIXED_ZOOM_10 = hash("FIXED_ZOOM_10")

local DISPLAY_WIDTH = tonumber(sys.get_config("display.width"))
local DISPLAY_HEIGHT = tonumber(sys.get_config("display.height"))

local WINDOW_WIDTH = DISPLAY_WIDTH
local WINDOW_HEIGHT = DISPLAY_HEIGHT


-- center camera to middle of screen
local OFFSET = vmath.vector3(DISPLAY_WIDTH / 2, DISPLAY_HEIGHT / 2, 0)

local MATRIX4 = vmath.matrix4()

local v4_tmp = vmath.vector4()
local v3_tmp = vmath.vector3()

local cameras = {}

--- projection providers (projectors)
-- a mapping of id to function to calculate and return a projection matrix
local projectors = {}

-- the default projector from the default render script
-- will stretch content
projectors[M.PROJECTOR.DEFAULT] = function(camera_id, near_z, far_z)
	return vmath.matrix4_orthographic(0, DISPLAY_WIDTH, 0, DISPLAY_HEIGHT, near_z, far_z)
end

-- setup a fixed aspect ratio projection that zooms in/out to fit the original viewport contents
-- regardless of window size
projectors[M.PROJECTOR.FIXED] = function(camera_id, near_z, far_z)
	local zoom_factor = math.min(WINDOW_WIDTH / DISPLAY_WIDTH, WINDOW_HEIGHT / DISPLAY_HEIGHT)
	local projected_width = WINDOW_WIDTH / zoom_factor
	local projected_height = WINDOW_HEIGHT / zoom_factor
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

-- setup a fixed aspect ratio projection without any zoom
projectors[M.PROJECTOR.FIXED_NOZOOM] = function(camera_id, near_z, far_z)
	local projected_width = WINDOW_WIDTH
	local projected_height = WINDOW_HEIGHT
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

local function create_fixed_zoom_projector(zoom_factor)
	return function(camera_id, near_z, far_z)
		local projected_width = WINDOW_WIDTH / zoom_factor
		local projected_height = WINDOW_HEIGHT / zoom_factor
		local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
		local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
		return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
	end
end

projectors[M.PROJECTOR.FIXED_ZOOM_2] = create_fixed_zoom_projector(2)
projectors[M.PROJECTOR.FIXED_ZOOM_3] = create_fixed_zoom_projector(3)
projectors[M.PROJECTOR.FIXED_ZOOM_4] = create_fixed_zoom_projector(4)
projectors[M.PROJECTOR.FIXED_ZOOM_5] = create_fixed_zoom_projector(5)
projectors[M.PROJECTOR.FIXED_ZOOM_6] = create_fixed_zoom_projector(6)
projectors[M.PROJECTOR.FIXED_ZOOM_7] = create_fixed_zoom_projector(7)
projectors[M.PROJECTOR.FIXED_ZOOM_8] = create_fixed_zoom_projector(8)
projectors[M.PROJECTOR.FIXED_ZOOM_9] = create_fixed_zoom_projector(9)
projectors[M.PROJECTOR.FIXED_ZOOM_10] = create_fixed_zoom_projector(10)


--- Add a custom projector
-- @param projector_id Unique id of the projector (hash)
-- @param projector_fn The function to call when the projection matrix needs to be calculated
-- The function will receive near_z and far_z as arguments
function M.add_projector(projector_id, projector_fn)
	projectors[projector_id] = projector_fn
end

--- Set the projector used by a camera
-- @param camera_id
-- @param projector_id The projector to use
function M.use_projector(camera_id, projector_id)
	assert(camera_id, "You must provide a camera id")
	assert(projector_id, "You must provide a projector id")
	local camera = cameras[camera_id]
	if camera then
		camera.projector_id = projector_id
	end
end


--- Set the window size
-- Call this from your render script to update the current window size
-- The width and height can later be retrieved through the M.get_window_size()
-- function. This is a convenience for use by custom projector functions
-- @param width Current window width
-- @param height Current window height
function M.set_window_size(width, height)
	WINDOW_WIDTH = width
	WINDOW_HEIGHT = height
end

--- Get the window size
-- @return width Current window width
-- @return height Current window height
function M.get_window_size()
	return WINDOW_WIDTH, WINDOW_HEIGHT
end

--- Get the display size (ie from game.project)
-- @return width Display width from game.project
-- @return height Display height from game.project
function M.get_display_size()
	return DISPLAY_WIDTH, DISPLAY_HEIGHT
end

local function calculate_projection(camera_id)
	local camera = cameras[camera_id]
	local projector_fn = projectors[camera.projector_id] or projectors[hash("DEFAULT")]
	return projector_fn(camera_id, camera.near_z, camera.far_z)
end

local function calculate_view(camera_id, camera_world_pos, offset)
	local rot = go.get_world_rotation(camera_id)
	local pos = camera_world_pos - vmath.rotate(rot, OFFSET)
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
-- @param settings Camera settings. Accepted values:
--		* near_z (number)
--		* far_z (number)
--		* projector_id (hash)
function M.init(camera_id, settings)
	assert(camera_id, "You must provide a camera id")
	assert(settings.near_z, "You must provide a near z-value")
	assert(settings.far_z, "You must provide a far z-value")
	assert(settings.projector_id, "You must provide a projector id")
	cameras[camera_id] = settings
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
-- * Limit camera to camera bounds (if any)
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
	
	local camera_world_pos = go.get_world_position(camera_id)
	local camera_world_to_local_diff = camera_world_pos - go.get_position(camera_id)
	if camera.follow then
		local target_pos = go.get_position(camera.follow.target)
		local target_world_pos = go.get_world_position(camera.follow.target)
		local new_pos
		if camera.deadzone then
			new_pos = vmath.vector3(camera_world_pos)
			local left_edge = camera_world_pos.x - camera.deadzone.left
			local right_edge = camera_world_pos.x + camera.deadzone.right
			local top_edge = camera_world_pos.y + camera.deadzone.top
			local bottom_edge = camera_world_pos.y - camera.deadzone.bottom
			if target_world_pos.x < left_edge then
				new_pos.x = new_pos.x - (left_edge - target_world_pos.x)
			elseif target_world_pos.x > right_edge then
				new_pos.x = new_pos.x + (target_world_pos.x - right_edge)
			end
			if target_world_pos.y > top_edge then
				new_pos.y = new_pos.y + (target_world_pos.y - top_edge)
			elseif target_world_pos.y < bottom_edge then
				new_pos.y = new_pos.y - (bottom_edge - target_world_pos.y)
			end
		else
			new_pos = target_world_pos
		end
		new_pos.z = camera_world_pos.z
		if camera.follow.lerp then
			camera_world_pos = vmath.lerp(camera.follow.lerp or 0.1, camera_world_pos, new_pos)
			camera_world_pos.z = new_pos.z
		else
			camera_world_pos = new_pos
		end
	end

	if camera.bounds then
		local bounds = camera.bounds
		local cp = M.world_to_screen(camera_id, vmath.vector3(camera_world_pos))
		local tr = M.world_to_screen(camera_id, bounds.top_right) - OFFSET
		local bl = M.world_to_screen(camera_id, bounds.bottom_left) + OFFSET
		
		cp.x = math.max(cp.x, bl.x)
		cp.x = math.min(cp.x, tr.x)
		cp.y = math.max(cp.y, bl.y)
		cp.y = math.min(cp.y, tr.y)
		
		camera_world_pos = M.screen_to_world(camera_id, cp)
	end

	go.set_position(camera_world_pos + camera_world_to_local_diff, camera_id)
	
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
	
	camera.view = calculate_view(camera_id, camera_world_pos, camera.shake and camera.shake.offset)	
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

--- Set the camera deadzone
-- @param camera_id
-- @param left Left edge of deadzone. Pass nil to remove deadzone.
-- @param top
-- @param right
-- @param bottom
function M.deadzone(camera_id, left, top, right, bottom)
	if left and right and top and bottom then
		cameras[camera_id].deadzone = {
			left = left,
			right = right,
			bottom = bottom,
			top = top,
		}
	else
		cameras[camera_id].deadzone = nil
	end
end


--- Set the camera bounds
-- @param camera_id
-- @param left Left edge of camera bounds. Pass nil to remove deadzone.
-- @param top
-- @param right
-- @param bottom
function M.bounds(camera_id, left, top, right, bottom)
	if left and top and right and bottom then
		cameras[camera_id].bounds = {
			left = left,
			right = right,
			bottom = bottom,
			top = top,
			bottom_left = vmath.vector3(left, bottom, 0),
			top_right = vmath.vector3(right, top, 0),
		}
	else
		cameras[camera_id].bounds = nil
	end
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
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	msg.post("@render:", "set_view_projection", { id = camera_id, view = view, projection = projection })
end


--- Convert screen coordinates to world coordinates based
-- on a specific camera's view and projection
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
-- @param screen Screen coordinates as a vector3
-- @return World coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.screen_to_world(camera_id, screen)
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	return M.unproject(view, projection, vmath.vector3(screen))
end


--- Convert world coordinates to screen coordinates based
-- on a specific camera's view and projection
-- Note: You need to have called update() at least once (this is done automatically
-- by the camera.script)
-- @param camera_id
-- @param world World coordinates as a vector3
-- @return Screen coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.world_to_screen(camera_id, world)
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	return M.project(view, projection, vmath.vector3(world))
end


--- Translate world coordinates to screen coordinates given a
-- view and projection matrix
-- @param view View matrix
-- @param projection Projection matrix
-- @param world World coordinates as a vector3
-- @return The mutated world coordinates (ie the same v3 object)
-- translated to screen coordinates
function M.project(view, projection, world)
	v4_tmp.x, v4_tmp.y, v4_tmp.z, v4_tmp.w = world.x, world.y, world.z, 1
	local v4 = projection * view * v4_tmp
	world.x = ((v4.x + 1) / 2) * DISPLAY_WIDTH
	world.y = ((v4.y + 1) / 2) * DISPLAY_HEIGHT
	world.z = ((v4.z + 1) / 2)
	return world
end


--- Translate screen coordinates to world coordinates given a
-- view and projection matrix 
-- @param view View matrix
-- @param projection Projection matrix
-- @param screen Screen coordinates as a vector3
-- @return The mutated screen coordinates (ie the same v3 object)
-- translated to world coordinates
function M.unproject(view, projection, screen)
	local x = (2 * screen.x / DISPLAY_WIDTH) - 1
	local y = (2 * screen.y / DISPLAY_HEIGHT) - 1
	local z = (2 * screen.z) - 1
	v4_tmp.x, v4_tmp.y, v4_tmp.z, v4_tmp.w = x, y, z, 1
	local v4 = vmath.inv(projection * view) * v4_tmp
	screen.x = v4.x
	screen.y = v4.y
	screen.z = v4.z
	return screen
end

return M
