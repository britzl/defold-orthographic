--- Camera module to use in combination with the camera.go or camera.script

local M = {}

local HIGH_DPI = (sys.get_config("display.high_dpi", "0") == "1")
local dpi_ratio = 1

M.SHAKE_BOTH = hash("both")
M.SHAKE_HORIZONTAL = hash("horizontal")
M.SHAKE_VERTICAL = hash("vertical")

M.PROJECTOR = {}
M.PROJECTOR.DEFAULT = hash("DEFAULT")
M.PROJECTOR.FIXED_AUTO = hash("FIXED_AUTO")
M.PROJECTOR.FIXED_ZOOM = hash("FIXED_ZOOM")

local DISPLAY_WIDTH = tonumber(sys.get_config("display.width")) or 960
local DISPLAY_HEIGHT = tonumber(sys.get_config("display.height")) or 640
local UPDATE_FREQUENCY = tonumber(sys.get_config("display.update_frequency") or sys.get_config("display.frame_cap"))
if UPDATE_FREQUENCY == 0 then UPDATE_FREQUENCY = 60 end

local WINDOW_WIDTH = DISPLAY_WIDTH
local WINDOW_HEIGHT = DISPLAY_HEIGHT


-- center camera to middle of screen
local OFFSET = vmath.vector3(DISPLAY_WIDTH / 2, DISPLAY_HEIGHT / 2, 0)

local VECTOR3_ZERO = vmath.vector3(0)
local VECTOR3_MINUS1_Z = vmath.vector3(0, 0, -1.0)
local VECTOR3_UP = vmath.vector3(0, 1.0, 0)

local MATRIX4 = vmath.matrix4()

local v4_tmp = vmath.vector4()
local v3_tmp = vmath.vector3()

local cameras = {}

--- projection providers (projectors)
-- a mapping of id to function to calculate and return a projection matrix
local projectors = {}

-- the default projector from the default render script
-- will stretch content
projectors[M.PROJECTOR.DEFAULT] = function(camera_id, near_z, far_z, zoom)
	return vmath.matrix4_orthographic(0, DISPLAY_WIDTH, 0, DISPLAY_HEIGHT, near_z, far_z)
end

-- setup a fixed aspect ratio projection that zooms in/out to fit the original viewport contents
-- regardless of window size
projectors[M.PROJECTOR.FIXED_AUTO] = function(camera_id, near_z, far_z, zoom)
	local zoom_factor = math.min(WINDOW_WIDTH / DISPLAY_WIDTH, WINDOW_HEIGHT / DISPLAY_HEIGHT) * zoom * dpi_ratio
	local projected_width = WINDOW_WIDTH / (zoom_factor / dpi_ratio)
	local projected_height = WINDOW_HEIGHT / (zoom_factor / dpi_ratio)
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

-- setup a fixed aspect ratio projection with a fixed zoom
projectors[M.PROJECTOR.FIXED_ZOOM] = function(camera_id, near_z, far_z, zoom)
	local projected_width = WINDOW_WIDTH / (zoom / dpi_ratio)
	local projected_height = WINDOW_HEIGHT / (zoom / dpi_ratio)
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end


-- http://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/
-- return vmath.lerp(1 - math.pow(t, dt), v1, v2)
-- https://www.gamasutra.com/blogs/ScottLembcke/20180404/316046/Improved_Lerp_Smoothing.php
local function lerp_with_dt(t, dt, v1, v2)
	local rate = UPDATE_FREQUENCY * math.log10(1 - t)
	return vmath.lerp(1 - math.pow(10, rate * dt), v1, v2)
	--return vmath.lerp(t, v1, v2)
end

--- Add a custom projector
-- @param projector_id Unique id of the projector (hash)
-- @param projector_fn The function to call when the projection matrix needs to be calculated
-- The function will receive near_z and far_z as arguments
function M.add_projector(projector_id, projector_fn)
	assert(projector_id, "You must provide a projector id")
	assert(projector_fn, "You must provide a projector function")
	projectors[projector_id] = projector_fn
end

--- Set the projector used by a camera
-- @param camera_id
-- @param projector_id The projector to use
function M.use_projector(camera_id, projector_id)
	assert(camera_id, "You must provide a camera id")
	assert(projector_id, "You must provide a projector id")
	assert(projectors[projector_id], "Unknown projection id")
	local camera = cameras[camera_id]
	msg.post(camera.url, "use_projection", { projection = projector_id })
end

--- Set window scaling factor (basically retina or no retina screen)
-- There is no built-in way to detect if Defold is running on a retina or
-- non retina screen. This information combined with the High DPI setting
-- in game.project can be used to ensure that the zoom behaves the same way
-- regardless of screen type and High DPI setting.
-- You can use an extension such as DefOS to get the window scaling factor.
-- @param scaling_factor Scaling factor of the display (1=normal, 2=retina)
function M.set_window_scaling_factor(scaling_factor)
	assert(scaling_factor, "You must provide a scaling factor")
	if HIGH_DPI then
		dpi_ratio = 1 / scaling_factor
	else
		dpi_ratio = 1
	end
end

--- Set the window size
-- Call this from your render script to update the current window size
-- The width and height can later be retrieved through the M.get_window_size()
-- function. This is a convenience for use by custom projector functions
-- @param width Current window width
-- @param height Current window height
function M.set_window_size(width, height)
	assert(width, "You must provide window width")
	assert(height, "You must provide window height")
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
	local projector_id = go.get(camera.url, "projection")
	assert(projectors[projector_id], "Unknown projection id")
	local near_z = go.get(camera.url, "near_z")
	local far_z = go.get(camera.url, "far_z")
	local zoom = go.get(camera.url, "zoom")
	camera.zoom = zoom
	local projector_fn = projectors[projector_id] or projectors[M.PROJECTOR.DEFAULT]
	return projector_fn(camera_id, near_z, far_z, zoom)
end



local function calculate_view(camera_id, camera_world_pos, offset)
	local rot = go.get_world_rotation(camera_id)
	local pos = camera_world_pos - vmath.rotate(rot, OFFSET)
	if offset then
		pos = pos + offset
	end

	local look_at = pos + vmath.rotate(rot, VECTOR3_MINUS1_Z)
	local up = vmath.rotate(rot, VECTOR3_UP)
	local view = vmath.matrix4_look_at(pos, look_at, up)
	return view
end


--- Initialize a camera
-- Note: This is called automatically from the init() function of the camera.script
-- @param camera_id
-- @param camera_script_url
function M.init(camera_id, camera_script_url, settings)
	assert(camera_id, "You must provide a camera id")
	assert(camera_script_url, "You must provide a camera script url")
	cameras[camera_id] = settings
	cameras[camera_id].url = camera_script_url
	cameras[camera_id].view = calculate_view(camera_id, go.get_world_position(camera_id))	
	cameras[camera_id].projection = calculate_projection(camera_id)
end


--- Finalize a camera
-- Note: This is called automatically from the final() function of the camera.script
-- @param camera_id
function M.final(camera_id)
	assert(camera_id, "You must provide a camera id")
	cameras[camera_id] = nil
end

--- Update a camera
-- When calling this function a number of things happen:
-- * Follow target game object (if any)
-- * Limit camera to camera bounds (if any)
-- * Shake the camera (if enabled)
-- * Recalculate the view and projection matrix
--
-- Note: This is called automatically from the camera.script
-- @param camera_id
-- @param dt
function M.update(camera_id, dt)
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	if not camera then
		return
	end

	local camera_world_pos = go.get_world_position(camera_id)
	local camera_world_to_local_diff = camera_world_pos - go.get_position(camera_id)
	local follow_enabled = go.get(camera.url, "follow")
	if follow_enabled then
		local follow_horizontal = go.get(camera.url, "follow_horizontal")
		local follow_vertical = go.get(camera.url, "follow_vertical")
		local follow = go.get(camera.url, "follow_target")
		local follow_offset = go.get(camera.url, "follow_offset")
		local target_world_pos = go.get_world_position(follow) + follow_offset
		local new_pos
		local deadzone_top = go.get(camera.url, "deadzone_top")
		local deadzone_left = go.get(camera.url, "deadzone_left")
		local deadzone_right = go.get(camera.url, "deadzone_right")
		local deadzone_bottom = go.get(camera.url, "deadzone_bottom")
		if deadzone_top ~= 0 or deadzone_left ~= 0 or deadzone_right ~= 0 or deadzone_bottom ~= 0 then
			new_pos = vmath.vector3(camera_world_pos)
			local left_edge = camera_world_pos.x - deadzone_left
			local right_edge = camera_world_pos.x + deadzone_right
			local top_edge = camera_world_pos.y + deadzone_top
			local bottom_edge = camera_world_pos.y - deadzone_bottom
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
		if not follow_vertical then
			new_pos.y = camera_world_pos.y
		end
		if not follow_horizontal then
			new_pos.x = camera_world_pos.x
		end
		local follow_lerp = go.get(camera.url, "follow_lerp")
		camera_world_pos = lerp_with_dt(follow_lerp, dt, camera_world_pos, new_pos)
		camera_world_pos.z = new_pos.z
	end

	local bounds_top = go.get(camera.url, "bounds_top")
	local bounds_left = go.get(camera.url, "bounds_left")
	local bounds_bottom = go.get(camera.url, "bounds_bottom")
	local bounds_right = go.get(camera.url, "bounds_right")
	if bounds_top ~= 0 or bounds_left ~= 0 or bounds_bottom ~= 0 or bounds_right ~= 0 then
		local cp = M.world_to_screen(camera_id, vmath.vector3(camera_world_pos))
		local tr = M.world_to_screen(camera_id, vmath.vector3(bounds_right, bounds_top, 0))
		local bl = M.world_to_screen(camera_id, vmath.vector3(bounds_left, bounds_bottom, 0))

		local tr_offset = tr - OFFSET
		local bl_offset = bl + OFFSET

		local bounds_width = tr.x - bl.x
		if bounds_width < DISPLAY_WIDTH then
			cp.x = bl.x + bounds_width / 2
		else
			cp.x = math.max(cp.x, bl_offset.x)
			cp.x = math.min(cp.x, tr_offset.x)
		end

		local bounds_height = tr.y - bl.y
		if bounds_height < DISPLAY_HEIGHT then
			cp.y = bl.y + bounds_height / 2
		else
			cp.y = math.max(cp.y, bl_offset.y)
			cp.y = math.min(cp.y, tr_offset.y)
		end

		camera_world_pos = M.screen_to_world(camera_id, cp)
	end

	go.set_position(camera_world_pos + camera_world_to_local_diff, camera_id)

	
	if camera.shake then
		camera.shake.duration = camera.shake.duration - dt
		if camera.shake.duration < 0 then
			camera.shake.cb()
			camera.shake = nil
		else
			if camera.shake.horizontal then
				camera.shake.offset.x = (DISPLAY_WIDTH * camera.shake.intensity) * (math.random() - 0.5)
			end
			if camera.shake.vertical then
				camera.shake.offset.y = (DISPLAY_WIDTH * camera.shake.intensity) * (math.random() - 0.5)
			end
		end
	end

	if camera.recoil then
		camera.recoil.time_left = camera.recoil.time_left - dt
		if camera.recoil.time_left < 0 then
			camera.recoil = nil
		else
			local t = camera.recoil.time_left / camera.recoil.duration
			camera.recoil.offset = vmath.lerp(t, VECTOR3_ZERO, camera.recoil.offset)
		end
	end

	local offset
	if camera.shake or camera.recoil then
		offset = VECTOR3_ZERO
		if camera.shake then
			offset = offset + camera.shake.offset
		end
		if camera.recoil then
			offset = offset + camera.recoil.offset
		end
	end
	camera.offset = offset
	camera.view = calculate_view(camera_id, camera_world_pos, offset)	
	camera.projection = calculate_projection(camera_id)
end


--- Follow a game object
-- @param camera_id
-- @param target The game object to follow
-- @param options Table with options
--		lerp - lerp to smoothly move the camera towards the target (default: nil)
-- 		offset - Offset from target position (default: nil)
--		horizontal - true if following target along horizontal axis (default: true)
--		vertical - true if following target along vertical axis (default: true)
function M.follow(camera_id, target, options, __offset)
	assert(camera_id, "You must provide a camera id")
	assert(target, "You must provide a target")

	-- handle old function signature where 3rd argument was lerp and 4th was offset
	local lerp = nil
	local offset = nil
	local vertical = true
	local horizontal = true
	if type(options) == "table" then
		lerp = options.lerp
		offset = options.lerp
		horizontal = options.horizontal
		vertical = options.vertical
	else
		lerp = options
		offset = __offset
	end
	
	msg.post(cameras[camera_id].url, "follow", {
		target = target,
		lerp = lerp,
		offset = offset,
		horizontal = horizontal,
		vertical = vertical,
	})
end


--- Unfollow a game object
-- @param camera_id
function M.unfollow(camera_id)
	assert(camera_id, "You must provide a camera id")
	msg.post(cameras[camera_id].url, "unfollow")
end

--- Set the camera deadzone
-- @param camera_id
-- @param left Left edge of deadzone. Pass nil to remove deadzone.
-- @param top
-- @param right
-- @param bottom
function M.deadzone(camera_id, left, top, right, bottom)
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	if left and right and top and bottom then
		msg.post(camera.url, "deadzone", { left = left, top = top, right = right, bottom = bottom })
	else
		msg.post(camera.url, "deadzone")
	end
end


--- Set the camera bounds
-- @param camera_id
-- @param left Left edge of camera bounds. Pass nil to remove bounds.
-- @param top
-- @param right
-- @param bottom
function M.bounds(camera_id, left, top, right, bottom)
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	if left and top and right and bottom then
		msg.post(camera.url, "bounds", { left = left, top = top, right = right, bottom = bottom })
	else
		msg.post(camera.url, "bounds")
	end
end


--- Shake a camera
-- @param camera_id
-- @param intensity Intensity of the shake in percent of screen width. Optional, default: 0.05.
-- @param duration Duration of the shake. Optional, default: 0.5s.
-- @param direction both|horizontal|vertical. Optional, default: both
-- @param cb Function to call when shake has completed. Optional
function M.shake(camera_id, intensity, duration, direction, cb)
	assert(camera_id, "You must provide a camera id")
	cameras[camera_id].shake = {
		intensity = intensity or 0.05,
		duration = duration or 0.5,
		horizontal = direction ~= M.SHAKE_VERTICAL or false,
		vertical = direction ~= M.SHAKE_HORIZONTAL or false,
		offset = vmath.vector3(0),
		cb = cb,
	}
end


--- Stop shaking a camera
-- @param camera_id
function M.stop_shaking(camera_id)
	assert(camera_id, "You must provide a camera id")
	cameras[camera_id].shake = nil
end


--- Simulate a recoil effect
-- @param camera_id
-- @param offset Amount to offset the camera with
-- @param duration Duration of the recoil. Optional, default: 0.5s.
function M.recoil(camera_id, offset, duration)
	assert(camera_id, "You must provide a strength id")
	cameras[camera_id].recoil = {
		offset = offset,
		duration = duration or 0.5,
		time_left = duration or 0.5,
	}
end


--- Set the zoom level of a camera
-- @param camera_id
-- @param zoom The zoom level of the camera
function M.set_zoom(camera_id, zoom)
	assert(camera_id, "You must provide a camera id")
	assert(zoom, "You must provide a zoom level")
	msg.post(cameras[camera_id].url, "zoom_to", { zoom = zoom })
end


--- Get the zoom level of a camera
-- @param camera_id
-- @return Current zoom level of the camera
function M.get_zoom(camera_id)
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].zoom
end


--- Get the projection matrix for a camera
-- @param camera_id
-- @return Projection matrix
function M.get_projection(camera_id)
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].projection
end


--- Get the view matrix for a specific camera, based on the camera position
-- and rotation
-- @param camera_id
-- @return View matrix
function M.get_view(camera_id)
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].view
end


--- Send the view and projection matrix for a camera to the render script
-- @param camera_id
function M.send_view_projection(camera_id)
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	local view = camera.view or MATRIX4
	local projection = camera.projection or MATRIX4
	msg.post("@render:", "set_view_projection", { id = camera_id, view = view, projection = projection })
end


--- Send the camera offset tp the render script
-- @param camera_id
function M.send_camera_offset(camera_id)
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	msg.post("@render:", "set_camera_offset", { id = camera_id, offset = camera.offset })
end


--- Convert screen coordinates to world coordinates based
-- on a specific camera's view and projection
-- Screen coordinates are the scaled coordinates provided by action.x and action.y
-- in on_input()
-- @param camera_id
-- @param screen Screen coordinates as a vector3
-- @return World coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.screen_to_world(camera_id, screen)
	assert(camera_id, "You must provide a camera id")
	assert(screen, "You must provide screen coordinates to convert")
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	return M.unproject(view, projection, vmath.vector3(screen))
end


--- Convert window coordinates to world coordinates based
-- on a specific camera's view and projection
-- Window coordinates are the non-scaled coordinates provided by action.screen_x
-- and action.screen_y in on_input()
-- @param camera_id
-- @param window Window coordinates as a vector3
-- @return World coordinates
function M.window_to_world(camera_id, window)
	assert(camera_id, "You must provide a camera id")
	assert(window, "You must provide window coordinates to convert")
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	local scale_x = window.x * dpi_ratio * DISPLAY_WIDTH / WINDOW_WIDTH
	local scale_y = window.y * dpi_ratio * DISPLAY_HEIGHT / WINDOW_HEIGHT
	local screen = vmath.vector3(scale_x, scale_y, 0)
	return M.unproject(view, projection, screen)
end


--- Convert world coordinates to screen coordinates based
-- on a specific camera's view and projection.
-- @param camera_id
-- @param world World coordinates as a vector3
-- @return Screen coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.world_to_screen(camera_id, world)
	assert(camera_id, "You must provide a camera id")
	assert(world, "You must provide world coordinates to convert")
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
	assert(view, "You must provide a view")
	assert(projection, "You must provide a projection")
	assert(world, "You must provide world coordinates to translate")
	v4_tmp.x, v4_tmp.y, v4_tmp.z, v4_tmp.w = world.x, world.y, world.z, 1
	local v4 = projection * view * v4_tmp
	world.x = ((v4.x + 1) / 2) * DISPLAY_WIDTH
	world.y = ((v4.y + 1) / 2) * DISPLAY_HEIGHT
	world.z = ((v4.z + 1) / 2)
	return world
end


local function unproject_xyz(inverse_view_projection, x, y, z)
	x = (2 * x / DISPLAY_WIDTH) - 1
	y = (2 * y / DISPLAY_HEIGHT) - 1
	z = (2 * z) - 1
	local inv = inverse_view_projection
	local x1 = x * inv.m00 + y * inv.m01 + z * inv.m02 + inv.m03
	local y1 = x * inv.m10 + y * inv.m11 + z * inv.m12 + inv.m13
	local z1 = x * inv.m20 + y * inv.m21 + z * inv.m22 + inv.m23
	return x1, y1, z1
end

--- Translate screen coordinates to world coordinates given a
-- view and projection matrix 
-- @param view View matrix
-- @param projection Projection matrix
-- @param screen Screen coordinates as a vector3
-- @return The mutated screen coordinates (ie the same v3 object)
-- translated to world coordinates
function M.unproject(view, projection, screen)
	assert(view, "You must provide a view")
	assert(projection, "You must provide a projection")
	assert(screen, "You must provide screen coordinates to translate")
	local inv = vmath.inv(projection * view)
	screen.x, screen.y, screen.z = unproject_xyz(inv, screen.x, screen.y, screen.z)
	return screen
end

--- Get the screen bounds as world coordinates, ie where in world space the
-- screen corners are
-- @param camera_id
-- @return bounds Vector4 where x is left, y is top, z is right and w is bottom
function M.screen_to_world_bounds(camera_id)
	assert(camera_id, "You must provide a camera id")
	local view = cameras[camera_id].view or MATRIX4
	local projection = cameras[camera_id].projection or MATRIX4
	local inv = vmath.inv(projection * view)
	local bl_x, bl_y = unproject_xyz(inv, 0, 0, 0)
	local br_x, br_y = unproject_xyz(inv, DISPLAY_WIDTH, 0, 0)
	local tl_x, tl_y = unproject_xyz(inv, 0, DISPLAY_HEIGHT, 0)
	return vmath.vector4(bl_x, tl_y, br_x, bl_y)
end

return M
