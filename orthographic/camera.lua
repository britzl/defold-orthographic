--- Camera module to use in combination with the camera.go or camera.script

local M = {}

M.ORTHOGRAPHIC_RENDER_SCRIPT_USED = false

M.MSG_ENABLE = hash("enable")
M.MSG_DISABLE = hash("disable")
M.MSG_UNFOLLOW = hash("unfollow")
M.MSG_FOLLOW = hash("follow")
M.MSG_FOLLOW_OFFSET = hash("follow_offset")
M.MSG_RECOIL = hash("recoil")
M.MSG_SHAKE = hash("shake")
M.MSG_SHAKE_COMPLETED = hash("shake_completed")
M.MSG_STOP_SHAKING = hash("stop_shaking")
M.MSG_DEADZONE = hash("deadzone")
M.MSG_BOUNDS = hash("bounds")
M.MSG_UPDATE_CAMERA = hash("update_camera")
M.MSG_ZOOM_TO = hash("zoom_to")
M.MSG_USE_PROJECTION = hash("use_projection")
M.MSG_VIEWPORT = hash("viewport")


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


local GUI_ADJUST = {
	[gui.ADJUST_FIT] = {sx=1, sy=1, ox=0, oy=0}, -- Fit
	[gui.ADJUST_ZOOM] = {sx=1, sy=1, ox=0, oy=0}, -- Zoom
	[gui.ADJUST_STRETCH] = {sx=1, sy=1, ox=0, oy=0}, -- Stretch
}

-- center camera to middle of screen
local OFFSET = vmath.vector3(DISPLAY_WIDTH / 2, DISPLAY_HEIGHT / 2, 0)

local VECTOR3_ZERO = vmath.vector3(0)
local VECTOR3_MINUS1_Z = vmath.vector3(0, 0, -1.0)
local VECTOR3_UP = vmath.vector3(0, 1.0, 0)

local MATRIX4 = vmath.matrix4()
local VECTOR4 = vmath.vector4()

local v4_tmp = vmath.vector4()
local v3_tmp = vmath.vector3()

local cameras = {}
local camera_ids = {}
local enabled_cameras = {}
-- track if the cameras list has changed or not
local cameras_dirty = true

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
	local camera = cameras[camera_id]
	local ww = camera.viewport and camera.viewport.z or WINDOW_WIDTH
	local wh = camera.viewport and camera.viewport.w or WINDOW_HEIGHT
	
	local zoom_factor = math.min(ww / DISPLAY_WIDTH, wh / DISPLAY_HEIGHT) * zoom * dpi_ratio
	local projected_width = ww / (zoom_factor / dpi_ratio)
	local projected_height = wh / (zoom_factor / dpi_ratio)
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

-- setup a fixed aspect ratio projection with a fixed zoom
projectors[M.PROJECTOR.FIXED_ZOOM] = function(camera_id, near_z, far_z, zoom)
	local camera = cameras[camera_id]
	local ww = camera.viewport and camera.viewport.z or WINDOW_WIDTH
	local wh = camera.viewport and camera.viewport.w or WINDOW_HEIGHT

	local projected_width = ww / (zoom / dpi_ratio)
	local projected_height = wh / (zoom / dpi_ratio)
	local xoffset = -(projected_width - DISPLAY_WIDTH) / 2
	local yoffset = -(projected_height - DISPLAY_HEIGHT) / 2
	return vmath.matrix4_orthographic(xoffset, xoffset + projected_width, yoffset, yoffset + projected_height, near_z, far_z)
end

local function log(s, ...)
	if s then print(s:format(...)) end
end

local function check_game_object(id)
	local ok, err = pcall(go.get_position, id)
	return ok
end

-- http://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/
-- return vmath.lerp(1 - math.pow(t, dt), v1, v2)
-- https://www.gamasutra.com/blogs/ScottLembcke/20180404/316046/Improved_Lerp_Smoothing.php
local function lerp_with_dt(t, dt, v1, v2)
	if dt == 0 then return vmath.lerp(t, v1, v2) end
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
-- @param camera_id or nil for the first camera
-- @param projector_id The projector to use
function M.use_projector(camera_id, projector_id)
	camera_id = camera_id or camera_ids[1]
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

--- Update the window size
-- @param width Current window width
-- @param height Current window height
local function update_window_size()
	local width, height = window.get_size()
	if width == 0 or height == 0 then
		return
	end
	if width == WINDOW_WIDTH and height == WINDOW_HEIGHT then
		return
	end
	WINDOW_WIDTH = width
	WINDOW_HEIGHT = height

	local sx = WINDOW_WIDTH / DISPLAY_WIDTH
	local sy = WINDOW_HEIGHT / DISPLAY_HEIGHT

	-- Fit
	local adjust = GUI_ADJUST[gui.ADJUST_FIT]
	local scale = math.min(sx, sy)
	adjust.sx = scale * 1 / sx
	adjust.sy = scale * 1 / sy
	adjust.ox = (WINDOW_WIDTH - DISPLAY_WIDTH * scale) * 0.5 / scale
	adjust.oy = (WINDOW_HEIGHT - DISPLAY_HEIGHT * scale) * 0.5 / scale

	-- Zoom
	adjust = GUI_ADJUST[gui.ADJUST_ZOOM]
	scale = math.max(sx, sy)
	adjust.sx = scale * 1 / sx
	adjust.sy = scale * 1 / sy
	adjust.ox = (WINDOW_WIDTH - DISPLAY_WIDTH * scale) * 0.5 / scale
	adjust.oy = (WINDOW_HEIGHT - DISPLAY_HEIGHT * scale) * 0.5 / scale

	-- Stretch
	adjust = GUI_ADJUST[gui.ADJUST_STRETCH]
	adjust.sx = 1
	adjust.sy = 1
	-- distorts to fit window, offsets always zero
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

local function calculate_projection(camera)
	local projection_id = camera.projection_id
	assert(projectors[projection_id], "Unknown projection id")
	local projector_fn = projectors[projection_id] or projectors[M.PROJECTOR.DEFAULT]
	return projector_fn(camera.id, camera.near_z, camera.far_z, camera.zoom)
end


local function calculate_view(camera, camera_world_pos, offset)
	local rot = go.get_world_rotation(camera.id)
	local pos = vmath.rotate(rot, OFFSET)
	if offset then
		pos.x = camera_world_pos.x - pos.x + offset.x
		pos.y = camera_world_pos.y - pos.y + offset.y
		pos.z = camera_world_pos.z - pos.z + offset.z
	else
		pos.x = camera_world_pos.x - pos.x
		pos.y = camera_world_pos.y - pos.y
		pos.z = camera_world_pos.z - pos.z
	end

	local look_at = vmath.rotate(rot, VECTOR3_MINUS1_Z)
	look_at.x = look_at.x + pos.x
	look_at.y = look_at.y + pos.y
	look_at.z = look_at.z + pos.z
	local up = vmath.rotate(rot, VECTOR3_UP)
	local view = vmath.matrix4_look_at(pos, look_at, up)
	return view
end

local function is_lesser_order(a, b)
	return a.order < b.order
end

local function refresh_cameras()
	if cameras_dirty then
		cameras_dirty = false
		local old_cam_count = #enabled_cameras
		local new_cam_count = 0
		for _, camera in pairs(cameras) do
			if camera.enabled then
				new_cam_count = new_cam_count + 1
				enabled_cameras[new_cam_count] = camera
			end
		end
		for i = new_cam_count + 1, old_cam_count do
			enabled_cameras[i] = nil
			camera_ids[i] = nil
		end
		table.sort(enabled_cameras, is_lesser_order)
		for i = 1, new_cam_count do
			camera_ids[i] = enabled_cameras[i].id
		end
	end
end

local function world_to_screen_mutable(viewport_w, viewport_h, viewport_l, viewport_b, view_projection, world)
	v4_tmp.x, v4_tmp.y, v4_tmp.z, v4_tmp.w = world.x, world.y, world.z, 1
	local wvp = view_projection * v4_tmp
	world.x = ((wvp.x + 1) / 2) * DISPLAY_WIDTH
	world.y = ((wvp.y + 1) / 2) * DISPLAY_HEIGHT
	world.z = ((wvp.z + 0) / 2)

	world.x = viewport_l + world.x * (viewport_w / DISPLAY_WIDTH)
	world.y = viewport_b + world.y * (viewport_h / DISPLAY_HEIGHT)
end

local function screen_to_world_mutable(viewport_w, viewport_h, viewport_l, viewport_b, inverse_view_projection, screen)
	local x = (screen.x - viewport_l) * (DISPLAY_WIDTH / viewport_w)
	local y = (screen.y - viewport_b) * (DISPLAY_HEIGHT / viewport_h)

	local x = (2 * x / DISPLAY_WIDTH) - 1
	local y = (2 * y / DISPLAY_HEIGHT) - 1
	local z = (2 * screen.z)
	local ivp = inverse_view_projection
	screen.x = x * ivp.m00 + y * ivp.m01 + z * ivp.m02 + ivp.m03
	screen.y = x * ivp.m10 + y * ivp.m11 + z * ivp.m12 + ivp.m13
	screen.z = x * ivp.m20 + y * ivp.m21 + z * ivp.m22 + ivp.m23
end

--- Initialize a camera
-- Note: This is called automatically from the init() function of the camera.script
-- @param camera_id
-- @param camera_script_url
function M.init(camera_id, camera_script_url, settings)
	assert(camera_id, "You must provide a camera id")
	assert(camera_script_url, "You must provide a camera script url")
	cameras[camera_id] = settings
	cameras_dirty = true
	local camera = cameras[camera_id]
	camera.id = camera_id
	camera.url = camera_script_url
	camera.projection_id = go.get(camera_script_url, "projection")
	camera.near_z = go.get(camera_script_url, "near_z")
	camera.far_z = go.get(camera_script_url, "far_z")
	camera.view = calculate_view(camera, go.get_world_position(camera_id))
	camera.projection = calculate_projection(camera)
	camera.viewport = vmath.vector4(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)

	if not sys.get_engine_info().is_debug then
		log = function() end
	end

	if not M.ORTHOGRAPHIC_RENDER_SCRIPT_USED then
		log("WARNING: orthographic.render_script not used. Did you forget to change render file in game.project?")
	end
end

--- Finalize a camera
-- Note: This is called automatically from the final() function of the camera.script
-- @param camera_id
function M.final(camera_id)
	assert(camera_id, "You must provide a camera id")
	-- check that a new camera with the same id but from a different go hasn't been
	-- replacing the camera that is being unregistered
	-- if this is the case we simply ignore the call to final()
	if cameras[camera_id].url == msg.url() then
		cameras[camera_id] = nil
		cameras_dirty = true
	end
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

	local enabled = go.get(camera.url, "enabled")
	local order = go.get(camera.url, "order")
	cameras_dirty = cameras_dirty or (camera.enabled ~= enabled)
	cameras_dirty = cameras_dirty or (camera.order ~= order)
	camera.enabled = enabled
	camera.order = order
	if not enabled then
		return
	end

	camera.projection_id = go.get(camera.url, "projection")
	camera.near_z = go.get(camera.url, "near_z")
	camera.far_z = go.get(camera.url, "far_z")
	camera.zoom = go.get(camera.url, "zoom")

	local viewport_top = go.get(camera.url, "viewport_top")
	local viewport_left = go.get(camera.url, "viewport_left")
	local viewport_bottom = go.get(camera.url, "viewport_bottom")
	local viewport_right = go.get(camera.url, "viewport_right")
	if viewport_top == 0 then
		viewport_top = WINDOW_HEIGHT
	end
	if viewport_right == 0 then
		viewport_right = WINDOW_WIDTH
	end
	camera.viewport.x = viewport_left
	camera.viewport.y = viewport_bottom
	camera.viewport.z = math.max(viewport_right - viewport_left, 1)
	camera.viewport.w = math.max(viewport_top - viewport_bottom, 1)

	update_window_size()

	local camera_world_pos = go.get_world_position(camera_id)
	local camera_world_to_local_diff = go.get_position(camera_id)
	camera_world_to_local_diff.x = camera_world_to_local_diff.x - camera_world_pos.x
	camera_world_to_local_diff.y = camera_world_to_local_diff.y - camera_world_pos.y
	camera_world_to_local_diff.z = camera_world_to_local_diff.z - camera_world_pos.z
	local follow_enabled = go.get(camera.url, "follow")
	if follow_enabled then
		local follow = go.get(camera.url, "follow_target")
		if not check_game_object(follow) then
			log("Camera '%s' has a follow target '%s' that does not exist", tostring(camera_id), tostring(follow))
		else
			local follow_horizontal = go.get(camera.url, "follow_horizontal")
			local follow_vertical = go.get(camera.url, "follow_vertical")
			local follow_offset = go.get(camera.url, "follow_offset")
			local new_pos = go.get_world_position(follow)
			new_pos.x = new_pos.x + follow_offset.x
			new_pos.y = new_pos.y + follow_offset.y
			new_pos.z = camera_world_pos.z
			local deadzone_top = go.get(camera.url, "deadzone_top")
			local deadzone_left = go.get(camera.url, "deadzone_left")
			local deadzone_right = go.get(camera.url, "deadzone_right")
			local deadzone_bottom = go.get(camera.url, "deadzone_bottom")
			if deadzone_top ~= 0 or deadzone_left ~= 0 or deadzone_right ~= 0 or deadzone_bottom ~= 0 then
				local left_edge = camera_world_pos.x - deadzone_left
				local right_edge = camera_world_pos.x + deadzone_right
				local top_edge = camera_world_pos.y + deadzone_top
				local bottom_edge = camera_world_pos.y - deadzone_bottom
				if new_pos.x < left_edge then
					new_pos.x = camera_world_pos.x - (left_edge - new_pos.x)
				elseif new_pos.x > right_edge then
					new_pos.x = camera_world_pos.x + (new_pos.x - right_edge)
				else
					new_pos.x = camera_world_pos.x
				end
				if new_pos.y > top_edge then
					new_pos.y = camera_world_pos.y + (new_pos.y - top_edge)
				elseif new_pos.y < bottom_edge then
					new_pos.y = camera_world_pos.y - (bottom_edge - new_pos.y)
				else
					new_pos.y = camera_world_pos.y
				end
			end
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
	end

	local bounds_top = go.get(camera.url, "bounds_top")
	local bounds_left = go.get(camera.url, "bounds_left")
	local bounds_bottom = go.get(camera.url, "bounds_bottom")
	local bounds_right = go.get(camera.url, "bounds_right")
	if bounds_top ~= 0 or bounds_left ~= 0 or bounds_bottom ~= 0 or bounds_right ~= 0 then
		local viewport = camera.viewport
		local viewport_w = viewport.z * DISPLAY_WIDTH / WINDOW_WIDTH
		local viewport_h = viewport.w * DISPLAY_HEIGHT / WINDOW_HEIGHT
		local viewport_l = viewport.x * DISPLAY_WIDTH / WINDOW_WIDTH
		local viewport_b = viewport.y * DISPLAY_HEIGHT / WINDOW_HEIGHT
		local view = camera.view or MATRIX4
		local projection = camera.projection or MATRIX4
		local view_projection = view * projection

		world_to_screen_mutable(viewport_w, viewport_h, viewport_l, viewport_b, view_projection, camera_world_pos)

		v3_tmp.x, v3_tmp.y, v3_tmp.z = bounds_right, bounds_top, 0
		world_to_screen_mutable(viewport_w, viewport_h, viewport_l, viewport_b, view_projection, v3_tmp)
		local tr_x, tr_y = v3_tmp.x, v3_tmp.y

		v3_tmp.x, v3_tmp.y, v3_tmp.z = bounds_left, bounds_bottom, 0
		world_to_screen_mutable(viewport_w, viewport_h, viewport_l, viewport_b, view_projection, v3_tmp)
		local bl_x, bl_y = v3_tmp.x, v3_tmp.y

		local bounds_width = tr_x - bl_x
		if bounds_width < DISPLAY_WIDTH then
			camera_world_pos.x = bl_x + bounds_width / 2
		else
			camera_world_pos.x = math.max(camera_world_pos.x, bl_x + OFFSET.x)
			camera_world_pos.x = math.min(camera_world_pos.x, tr_x - OFFSET.x)
		end

		local bounds_height = tr_y - bl_y
		if bounds_height < DISPLAY_HEIGHT then
			camera_world_pos.y = bl_y + bounds_height / 2
		else
			camera_world_pos.y = math.max(camera_world_pos.y, bl_y + OFFSET.y)
			camera_world_pos.y = math.min(camera_world_pos.y, tr_y - OFFSET.y)
		end

		screen_to_world_mutable(viewport_w, viewport_h, viewport_l, viewport_b, vmath.inv(view_projection), camera_world_pos)
	end

	v3_tmp.x = camera_world_pos.x + camera_world_to_local_diff.x
	v3_tmp.y = camera_world_pos.y + camera_world_to_local_diff.y
	v3_tmp.z = camera_world_pos.z + camera_world_to_local_diff.z
	go.set_position(v3_tmp, camera_id)


	local shake = camera.shake
	if shake then
		shake.duration = shake.duration - dt
		if shake.duration < 0 then
			if shake.cb then shake.cb() end
			camera.shake, shake = nil, nil
		else
			if shake.horizontal then
				shake.offset.x = (DISPLAY_WIDTH * shake.intensity) * (math.random() - 0.5)
			end
			if shake.vertical then
				shake.offset.y = (DISPLAY_WIDTH * shake.intensity) * (math.random() - 0.5)
			end
		end
	end

	local recoil = camera.recoil
	if recoil then
		recoil.time_left = recoil.time_left - dt
		if recoil.time_left < 0 then
			camera.recoil, recoil = nil, nil
		else
			local t = recoil.time_left / recoil.duration
			recoil.offset = vmath.lerp(t, VECTOR3_ZERO, recoil.offset)
		end
	end

	if shake or recoil then
		local offset = camera.offset
		if offset then
			offset.x = 0
			offset.y = 0
			offset.z = 0
		else
			offset = vmath.vector3()
			camera.offset = offset
		end
		if shake then
			offset.x = offset.x + shake.offset.x
			offset.y = offset.y + shake.offset.y
			offset.z = offset.z + shake.offset.z
		end
		if recoil then
			offset.x = offset.x + recoil.offset.x
			offset.y = offset.y + recoil.offset.y
			offset.z = offset.z + recoil.offset.z
		end
	else
		camera.offset = nil
	end

	camera.view = calculate_view(camera, camera_world_pos, camera.offset)
	camera.projection = calculate_projection(camera)

	refresh_cameras()
end

--- Get list of camera ids
-- @return List of camera ids
function M.get_cameras()
	refresh_cameras()
	return camera_ids
end

--- Follow a game object
-- @param camera_id or nil for the first camera
-- @param target The game object to follow
-- @param options Table with options
--		lerp - lerp to smoothly move the camera towards the target (default: nil)
-- 		offset - Offset from target position (default: nil)
--		horizontal - true if following target along horizontal axis (default: true)
--		vertical - true if following target along vertical axis (default: true)
--		immediate - true if camera should be immediately positioned on the target
function M.follow(camera_id, target, options)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(target, "You must provide a target")
	local lerp = options and options.lerp
	local offset = options and options.offset
	local horizontal = options and options.horizontal
	local vertical = options and options.vertical
	local immediate = options and options.immediate
	if horizontal == nil then horizontal = true end
	if vertical == nil then vertical = true end
	
	msg.post(cameras[camera_id].url, M.MSG_FOLLOW, {
		target = target,
		lerp = lerp,
		offset = offset,
		horizontal = horizontal,
		vertical = vertical,
		immediate = immediate,
	})
end


--- Unfollow a game object
-- @param camera_id or nil for the first camera
function M.unfollow(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	msg.post(cameras[camera_id].url, M.MSG_UNFOLLOW)
end


--- Change the camera follow offset
-- @param camera_id or nil for the first camera
-- @param offset - Offset from target position
function M.follow_offset(camera_id, offset)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(offset, "You must provide an offset")
	msg.post(cameras[camera_id].url, M.MSG_FOLLOW_OFFSET, { offset = offset })
end


--- Set the camera deadzone
-- @param camera_id or nil for the first camera
-- @param left Left edge of deadzone. Pass nil to remove deadzone.
-- @param top
-- @param right
-- @param bottom
function M.deadzone(camera_id, left, top, right, bottom)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	if left and right and top and bottom then
		msg.post(camera.url, M.MSG_DEADZONE, { left = left, top = top, right = right, bottom = bottom })
	else
		msg.post(camera.url, M.MSG_DEADZONE)
	end
end


--- Set the camera bounds
-- @param camera_id or nil for the first camera
-- @param left Left edge of camera bounds. Pass nil to remove bounds.
-- @param top
-- @param right
-- @param bottom
function M.bounds(camera_id, left, top, right, bottom)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	if left and top and right and bottom then
		msg.post(camera.url, M.MSG_BOUNDS, { left = left, top = top, right = right, bottom = bottom })
	else
		msg.post(camera.url, M.MSG_BOUNDS)
	end
end


--- Shake a camera
-- @param camera_id or nil for the first camera
-- @param intensity Intensity of the shake in percent of screen width. Optional, default: 0.05.
-- @param duration Duration of the shake. Optional, default: 0.5s.
-- @param direction both|horizontal|vertical. Optional, default: both
-- @param cb Function to call when shake has completed. Optional
function M.shake(camera_id, intensity, duration, direction, cb)
	camera_id = camera_id or camera_ids[1]
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
-- @param camera_id or nil for the first camera
function M.stop_shaking(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	cameras[camera_id].shake = nil
end


--- Simulate a recoil effect
-- @param camera_id or nil for the first camera
-- @param offset Amount to offset the camera with
-- @param duration Duration of the recoil. Optional, default: 0.5s.
function M.recoil(camera_id, offset, duration)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	cameras[camera_id].recoil = {
		offset = offset,
		duration = duration or 0.5,
		time_left = duration or 0.5,
	}
end


--- Set the zoom level of a camera
-- @param camera_id or nil for the first camera
-- @param zoom The zoom level of the camera
function M.set_zoom(camera_id, zoom)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(zoom, "You must provide a zoom level")
	local camera = cameras[camera_id]
	msg.post(camera.url, M.MSG_ZOOM_TO, { zoom = zoom })
	camera.zoom = zoom
	camera.projection = calculate_projection(camera)
end


--- Get the zoom level of a camera
-- @param camera_id or nil for the first camera
-- @return Current zoom level of the camera
function M.get_zoom(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].zoom
end


--- Get the projection matrix for a camera
-- @param camera_id or nil for the first camera
-- @return Projection matrix
function M.get_projection(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].projection
end


--- Get the projection id for a camera
-- @param camera_id or nil for the first camera
-- @return Projection id
function M.get_projection_id(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].projection_id
end


--- Get the view matrix for a specific camera, based on the camera position
-- and rotation
-- @param camera_id or nil for the first camera
-- @return View matrix
function M.get_view(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].view
end


--- Get the viewport for a specific camera
-- @param camera_id or nil for the first camera
-- @return Viewport (vector4)
function M.get_viewport(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].viewport
end


--- Get the offset for a specific camera
-- @param camera_id or nil for the first camera
-- @return Offset (vector3)
function M.get_offset(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return cameras[camera_id].offset
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


--- Convert screen coordinates to world coordinates based
-- on a specific camera's view and projection
-- Screen coordinates are the scaled coordinates provided by action.x and action.y
-- in on_input()
-- @param camera_id or nil for the first camera
-- @param screen Screen coordinates as a vector3
-- @return World coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.screen_to_world(camera_id, screen)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(screen, "You must provide screen coordinates to convert")
	local camera = cameras[camera_id]
	local view = camera.view or MATRIX4
	local projection = camera.projection or MATRIX4
	local viewport = camera.viewport or VECTOR4
	local viewport_width = viewport.z * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_height = viewport.w * DISPLAY_HEIGHT / WINDOW_HEIGHT
	local viewport_left = viewport.x * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_bottom = viewport.y * DISPLAY_HEIGHT / WINDOW_HEIGHT

	local s = vmath.vector3(screen)
	s.x = (s.x - viewport_left) * (DISPLAY_WIDTH / viewport_width)
	s.y = (s.y - viewport_bottom) * (DISPLAY_HEIGHT / viewport_height)

	return M.unproject(view, projection, s)
end


--- Convert window coordinates to world coordinates based
-- on a specific camera's view and projection
-- Window coordinates are the non-scaled coordinates provided by action.screen_x
-- and action.screen_y in on_input()
-- @param camera_id or nil for the first camera
-- @param window Window coordinates as a vector3
-- @return World coordinates
function M.window_to_world(camera_id, window)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(window, "You must provide window coordinates to convert")
	local camera = cameras[camera_id]
	local view = camera.view or MATRIX4
	local projection = camera.projection or MATRIX4
	local viewport = camera.viewport or VECTOR4
	local viewport_width = viewport.z * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_height = viewport.w * DISPLAY_HEIGHT / WINDOW_HEIGHT
	local viewport_left = viewport.x * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_bottom = viewport.y * DISPLAY_HEIGHT / WINDOW_HEIGHT
	local scale_x = window.x * dpi_ratio * DISPLAY_WIDTH / WINDOW_WIDTH
	local scale_y = window.y * dpi_ratio * DISPLAY_HEIGHT / WINDOW_HEIGHT

	local screen = vmath.vector3(scale_x, scale_y, 0)
	screen.x = (screen.x - viewport_left) * (DISPLAY_WIDTH / viewport_width)
	screen.y = (screen.y - viewport_bottom) * (DISPLAY_HEIGHT / viewport_height)
	return M.unproject(view, projection, screen)
end

--- Convert world coordinates to screen coordinates based
-- on a specific camera's view and projection.
-- @param camera_id or nil for the first camera
-- @param world World coordinates as a vector3
-- @return Screen coordinates
-- http://webglfactory.blogspot.se/2011/05/how-to-convert-world-to-screen.html
function M.world_to_screen(camera_id, world, adjust_mode)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(world, "You must provide world coordinates to convert")
	local camera = cameras[camera_id]
	local view = camera.view or MATRIX4
	local projection = camera.projection or MATRIX4
	local viewport = camera.viewport or VECTOR4
	local viewport_width = viewport.z * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_height = viewport.w * DISPLAY_HEIGHT / WINDOW_HEIGHT
	local viewport_left = viewport.x * DISPLAY_WIDTH / WINDOW_WIDTH
	local viewport_bottom = viewport.y * DISPLAY_HEIGHT / WINDOW_HEIGHT

	local screen = M.project(view, projection, vmath.vector3(world))
	screen.x = viewport_left + screen.x * (viewport_width / DISPLAY_WIDTH)
	screen.y = viewport_bottom + screen.y * (viewport_height / DISPLAY_HEIGHT)
	if adjust_mode then
		screen.x = (screen.x / GUI_ADJUST[adjust_mode].sx) - GUI_ADJUST[adjust_mode].ox
		screen.y = (screen.y / GUI_ADJUST[adjust_mode].sy) - GUI_ADJUST[adjust_mode].oy
	end
	return vmath.vector3(screen.x, screen.y, screen.z)
end

--- Convert world coordinates to window coordinates based
-- on a specific camera's view and projection
-- Window coordinates are the non-scaled coordinates provided by action.screen_x
-- and action.screen_y in on_input()
-- @param camera_id or nil for the first camera
-- @param world World coordinates as a vector3
-- @return window coordinates
function M.world_to_window(camera_id, world)
    camera_id = camera_id or camera_ids[1]
    assert(camera_id, "You must provide a camera id")
    assert(world, "You must provide world coordinates to convert")
    local camera = cameras[camera_id]
    local view = camera.view or MATRIX4
    local projection = camera.projection or MATRIX4
    local screen = M.project(view, projection, vmath.vector3(world))
    local scale_x = screen.x / (dpi_ratio * DISPLAY_WIDTH / WINDOW_WIDTH)
    local scale_y = screen.y / (dpi_ratio * DISPLAY_HEIGHT / WINDOW_HEIGHT)
    return vmath.vector3(scale_x, scale_y, 0)
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
	world.z = ((v4.z + 0) / 2)
	return world
end


local function unproject_xyz(inverse_view_projection, x, y, z)
	x = (2 * x / DISPLAY_WIDTH) - 1
	y = (2 * y / DISPLAY_HEIGHT) - 1
	z = (2 * z)
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
-- @param camera_id or nil for the first camera
-- @return bounds Vector4 where x is left, y is top, z is right and w is bottom
function M.screen_to_world_bounds(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	local view = camera.view or MATRIX4
	local projection = camera.projection or MATRIX4
	local inv = vmath.inv(projection * view)
	local bl_x, bl_y = unproject_xyz(inv, 0, 0, 0)
	local br_x, br_y = unproject_xyz(inv, DISPLAY_WIDTH, 0, 0)
	local tl_x, tl_y = unproject_xyz(inv, 0, DISPLAY_HEIGHT, 0)
	return vmath.vector4(bl_x, tl_y, br_x, bl_y)
end

return M
