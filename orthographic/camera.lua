--- Camera module to use in combination with the camera.go or camera.script

local M = {}

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
M.MSG_SET_AUTOMATIC_ZOOM = hash("set_automatic_zoom")
M.MSG_VIEWPORT = hash("viewport")

local dpi_ratio = nil

M.SHAKE_BOTH = hash("both")
M.SHAKE_HORIZONTAL = hash("horizontal")
M.SHAKE_VERTICAL = hash("vertical")

M.PROJECTOR = {}
M.PROJECTOR.FIXED_AUTO = hash("FIXED_AUTO")
M.PROJECTOR.FIXED_ZOOM = hash("FIXED_ZOOM")

local DISPLAY_WIDTH = sys.get_config_number("display.width") or 960
local DISPLAY_HEIGHT = sys.get_config_number("display.height") or 640
local UPDATE_FREQUENCY = sys.get_config_number("display.update_frequency") or sys.get_config_number("display.frame_cap")
if UPDATE_FREQUENCY == 0 then UPDATE_FREQUENCY = 60 end

local WINDOW_WIDTH = DISPLAY_WIDTH
local WINDOW_HEIGHT = DISPLAY_HEIGHT
local WINDOW_MIDDLE = vmath.vector3(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2, 0)

local VECTOR3_ZERO = vmath.vector3(0)

local cameras = {}
local camera_ids = {}
-- track if the cameras list has changed or not
local cameras_dirty = true


local function log(s, ...)
	if s then print(s:format(...)) end
end

local function check_game_object(id)
	return go.exists(id)
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


function M.add_projector()
	error("add_projector() is deprecated")
end
function M.use_projector()
	error("use_projector() is deprecated")
end
function M.get_projection_id()
	error("get_projection_id() is deprecated")
end
function M.send_view_projection()
	error("send_view_projection() is deprecated")
end
function M.set_window_scaling_factor(scaling_factor)
	error("set_window_scaling_factor() is deprecated")
end
function M.set_dpi_ratio(ratio)
	error("set_dpi_ratio() is deprecated")
end
function M.project(view, projection, world)
	error("project() is deprecated")
end
function M.window_to_world(camera_id, window)
	error("window_to_world() is deprecated")
end
function M.world_to_window(camera_id, world)
	error("world_to_window() is deprecated")
end
function M.unproject(view, projection, screen)
	error("unproject() is deprecated")
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
	WINDOW_MIDDLE.x = width / 2
	WINDOW_MIDDLE.y = height / 2
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

local function refresh_cameras()
	if cameras_dirty then
		cameras_dirty = false
		local enabled_cameras = {}
		for camera_id,camera in pairs(cameras) do
			if camera.enabled then
				enabled_cameras[#enabled_cameras + 1] = camera
			end
		end
		table.sort(enabled_cameras, function(a, b)
			return b.order > a.order
		end)
		if #enabled_cameras ~= #camera_ids then
			camera_ids = {}
		end
		for i=1,#enabled_cameras do
			camera_ids[i] = enabled_cameras[i].id
		end
	end
end

local function calculate_auto_zoom(camera)
	local viewport = camera.viewport
	local ww = (viewport.z or WINDOW_WIDTH) / dpi_ratio
	local wh = (viewport.w or WINDOW_HEIGHT) / dpi_ratio

	return math.min(ww / DISPLAY_WIDTH, wh / DISPLAY_HEIGHT)
end

local function update_from_properties(camera)
	-- from camera component
	camera.view = go.get(camera.component_url, "view")
	camera.projection = go.get(camera.component_url, "projection")

	-- from script component
	camera.near_z = go.get(camera.url, "near_z")
	camera.far_z = go.get(camera.url, "far_z")
	camera.zoom = go.get(camera.url, "zoom")
	camera.automatic_zoom = go.get(camera.url, "automatic_zoom")
	if camera.automatic_zoom then
		local zoom = calculate_auto_zoom(camera)
		camera.zoom = zoom
		msg.post(camera.url, M.MSG_ZOOM_TO, { zoom = zoom })
	end
end


local function update_viewport(camera)
	local viewport_top = go.get(camera.url, "viewport_top")
	local viewport_left = go.get(camera.url, "viewport_left")
	local viewport_bottom = go.get(camera.url, "viewport_bottom")
	local viewport_right = go.get(camera.url, "viewport_right")
	if viewport_top == 0 then
		viewport_top = WINDOW_HEIGHT
	else
		viewport_top = viewport_top * dpi_ratio
	end
	if viewport_right == 0 then
		viewport_right = WINDOW_WIDTH
	else
		viewport_right = viewport_right * dpi_ratio
	end
	if viewport_left ~= 0 then
		viewport_left = viewport_left * dpi_ratio
	end
	if viewport_bottom ~= 0 then
		viewport_bottom = viewport_bottom * dpi_ratio
	end
	camera.viewport.x = viewport_left
	camera.viewport.y = viewport_bottom
	camera.viewport.z = math.max(viewport_right - viewport_left, 1)
	camera.viewport.w = math.max(viewport_top - viewport_bottom, 1)
end

local function shake(camera, dt)
	if not camera.shake then return end

	camera.shake.duration = camera.shake.duration - dt
	if camera.shake.duration < 0 then
		if camera.shake.cb then camera.shake.cb() end
		camera.shake = nil
	else
		if camera.shake.horizontal then
			camera.shake.offset.x = (DISPLAY_WIDTH * camera.shake.intensity) * (math.random() - 0.5)
		end
		if camera.shake.vertical then
			camera.shake.offset.y = (DISPLAY_HEIGHT * camera.shake.intensity) * (math.random() - 0.5)
		end
	end
end

local function recoil(camera, dt)
	if not camera.recoil then return end

	camera.recoil.time_left = camera.recoil.time_left - dt
	if camera.recoil.time_left < 0 then
		camera.recoil = nil
	else
		local t = camera.recoil.time_left / camera.recoil.duration
		camera.recoil.offset = vmath.lerp(t, VECTOR3_ZERO, camera.recoil.offset)
		camera.recoil.offset.z = 0
	end
end

local function update_offset(camera)
	local offset = VECTOR3_ZERO
	camera.previous_offset = camera.offset or VECTOR3_ZERO
	if camera.shake or camera.recoil then
		if camera.shake then
			offset = offset + camera.shake.offset
		end
		if camera.recoil then
			offset = offset + camera.recoil.offset
		end
		offset.z = 0
	end
	camera.offset = offset
end

local function follow(camera, dt, camera_world_pos)
	local follow_enabled = go.get(camera.url, "follow")
	if follow_enabled then
		local follow_target = go.get(camera.url, "follow_target")
		if not check_game_object(follow_target) then
			log("Camera '%s' has a follow target '%s' that does not exist", tostring(camera.id), tostring(follow_target))
		else
			local follow_horizontal = go.get(camera.url, "follow_horizontal")
			local follow_vertical = go.get(camera.url, "follow_vertical")
			local follow_offset = go.get(camera.url, "follow_offset")
			local target_world_pos = go.get_world_position(follow_target) + follow_offset
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
			local lerped_pos = lerp_with_dt(follow_lerp, dt, camera_world_pos, new_pos)
			camera_world_pos.x = lerped_pos.x
			camera_world_pos.y = lerped_pos.y
			camera_world_pos.z = new_pos.z
		end
	end
end

local function apply_bounds(camera, camera_world_pos)
	local bounds_top = go.get(camera.url, "bounds_top")
	local bounds_left = go.get(camera.url, "bounds_left")
	local bounds_bottom = go.get(camera.url, "bounds_bottom")
	local bounds_right = go.get(camera.url, "bounds_right")
	if bounds_top ~= 0 or bounds_left ~= 0 or bounds_bottom ~= 0 or bounds_right ~= 0 then
		local camera_id = camera.id
		local cp = M.world_to_screen(camera_id, vmath.vector3(camera_world_pos))
		local tr = M.world_to_screen(camera_id, vmath.vector3(bounds_right, bounds_top, 0))
		local bl = M.world_to_screen(camera_id, vmath.vector3(bounds_left, bounds_bottom, 0))
		local tr_offset = tr - WINDOW_MIDDLE
		local bl_offset = bl + WINDOW_MIDDLE

		local bounds_width = tr.x - bl.x
		if bounds_width < WINDOW_WIDTH then
			cp.x = bl.x + bounds_width / 2
		else
			cp.x = math.max(cp.x, bl_offset.x)
			cp.x = math.min(cp.x, tr_offset.x)
		end

		local bounds_height = tr.y - bl.y
		if bounds_height < WINDOW_HEIGHT then
			cp.y = bl.y + bounds_height / 2
		else
			cp.y = math.max(cp.y, bl_offset.y)
			cp.y = math.min(cp.y, tr_offset.y)
		end

		local new_camera_position = M.screen_to_world(camera_id, cp)
		camera_world_pos.x = new_camera_position.x
		camera_world_pos.y = new_camera_position.y
		camera_world_pos.z = new_camera_position.z
	end
end

--- Initialize a camera
-- Note: This is called automatically from the init() function of the camera.script
-- @param camera_id
-- @param camera_script_url
function M.init(camera_id, _, settings)
	if not dpi_ratio then
		-- from defold 1.10.0
		if window.get_display_scale then
			dpi_ratio = window.get_display_scale()
		else
			local ww,wh = window.get_size()
			local dw,dh = sys.get_config_int("display.width"), sys.get_config_int("display.height")
			dpi_ratio = math.min(ww / dw, wh / dh)
		end
	end

	assert(camera_id, "You must provide a camera id")
	cameras[camera_id] = settings
	cameras_dirty = true
	local camera = cameras[camera_id]
	camera.id = camera_id
	camera.url = msg.url(nil, camera_id, "script")
	camera.component_url = msg.url(nil, camera_id, "camera")
	camera.viewport = vmath.vector4()
	camera.offset = vmath.vector3()
	camera.previous_offset = vmath.vector3()
	update_window_size()
	update_from_properties(camera)
	update_viewport(camera)

	if not sys.get_engine_info().is_debug then
		log = function() end
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

	go.update_world_transform(camera_id)
	local camera_world_pos = go.get_world_position(camera_id)
	local camera_world_to_local_diff = camera_world_pos - go.get_position(camera.id)

	update_window_size()
	update_from_properties(camera)
	update_viewport(camera)
	follow(camera, dt, camera_world_pos)
	apply_bounds(camera, camera_world_pos)
	shake(camera, dt)
	recoil(camera, dt)
	update_offset(camera) -- must be called after shake() and recoil()

	local new_camera_position = camera_world_pos + camera_world_to_local_diff + camera.offset - camera.previous_offset
	go.set_position(new_camera_position, camera_id)
	
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
	assert(camera_id, "You must provide a strength id")
	cameras[camera_id].recoil = {
		offset = offset,
		duration = duration or 0.5,
		time_left = duration or 0.5,
	}
end

function M.get_automatic_zoom(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	return camera.automatic_zoom
end

function M.set_automatic_zoom(camera_id, enabled)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local camera = cameras[camera_id]
	msg.post(camera.url, M.MSG_SET_AUTOMATIC_ZOOM, { enabled = enabled})
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
	return camera.get_projection(cameras[camera_id].component_url)
end

--- Get the view matrix for a specific camera, based on the camera position
-- and rotation
-- @param camera_id or nil for the first camera
-- @return View matrix
function M.get_view(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	return camera.get_view(cameras[camera_id].component_url)
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

--- Convert screen coordinates to world coordinates based
-- on a specific camera's view and projection
-- Screen coordinates are the coordinates provided by action.screen_x and action.screen_y
-- in on_input()
-- @param camera_id or nil for the first camera
-- @param screen Screen coordinates as a vector3
-- @return World coordinates
function M.screen_to_world(camera_id, screen)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(screen, "You must provide screen coordinates to convert")
	return camera.screen_to_world(vmath.vector3(screen), cameras[camera_id].component_url)
end

--- Convert world coordinates to screen coordinates based
-- on a specific camera's view and projection.
-- @param camera_id or nil for the first camera
-- @param world World coordinates as a vector3
-- @return Screen coordinates
function M.world_to_screen(camera_id, world)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	assert(world, "You must provide world coordinates to convert")
	return camera.world_to_screen(world, cameras[camera_id].component_url)
end

--- Get the screen bounds as world coordinates, ie where in world space the
-- screen corners are
-- @param camera_id or nil for the first camera
-- @return bounds Vector4 where x is left, y is top, z is right and w is bottom
function M.screen_to_world_bounds(camera_id)
	camera_id = camera_id or camera_ids[1]
	assert(camera_id, "You must provide a camera id")
	local url = cameras[camera_id].component_url
	local ww, wh = window.get_size()
	local bl = camera.screen_to_world(vmath.vector3(0, 0, 0), url)
	local tr = camera.screen_to_world(vmath.vector3(ww, wh, 0), url)
	return vmath.vector4(bl.x, tr.y, tr.x, bl.y)
end

return M