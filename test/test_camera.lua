local deftest = require "deftest.deftest"
local telescope = require "deftest.telescope"
local camera = require "orthographic.camera"

local WIDTH = tonumber(sys.get_config("display.width"))
local HEIGHT = tonumber(sys.get_config("display.height"))
local DISPLAY_CENTER = vmath.vector3(WIDTH / 2, HEIGHT / 2, 0)
local HIGHDPI = (sys.get_config("display.high_dpi", "0") == "1")

telescope.make_assertion(
	"xy",
	function(_, v3, x, y)
		local ex = math.floor(v3.x)
		local ey = math.floor(v3.y)
		return telescope.assertion_message_prefix .. ("x to be %s but it was %s and y to be %s but it was %s"):format(x, ex, y, ey)
	end,
	function(v3, x, y)
		if math.floor(v3.x) ~= x or math.floor(v3.y) ~= y then
			return false, "Expected x and y to match"
		end
		return true
	end
)

local function wait(seconds)
	local co = coroutine.running()
	timer.delay(seconds, false, function()
		coroutine.resume(co)
	end)
	coroutine.yield()
end

return function()

	local ratio = HIGHDPI and 2 or 1
	local camera_id = nil
	local function create_camera(pos)
		camera_id = factory.create("#camerafactory", pos)
	end

	describe("camera", function()
		before(function()
		end)

		after(function()
			if camera_id then
				go.delete(camera_id)
			end
		end)

		it("should convert from screen to world coordinates", function()
			local camera_pos = vmath.vector3(WIDTH / 2, HEIGHT / 2, 0)
			create_camera(camera_pos)
			camera.use_projector(camera_id, camera.PROJECTOR.DEFAULT)
			camera.set_zoom(camera_id, 1)
			wait(0.2)
			local world = camera.screen_to_world(camera_id, DISPLAY_CENTER)
			assert_xy(world, camera_pos.x, camera_pos.y)
			world = camera.screen_to_world(camera_id, DISPLAY_CENTER + vmath.vector3(100, 100, 0))
			assert_xy(world, camera_pos.x + 100, camera_pos.y + 100)

			camera.use_projector(camera_id, camera.PROJECTOR.FIXED_ZOOM)
			camera.set_zoom(camera_id, 2)
			wait(0.2)
			world = camera.screen_to_world(camera_id, DISPLAY_CENTER)
			assert_xy(world, camera_pos.x, camera_pos.y)
			world = camera.screen_to_world(camera_id, DISPLAY_CENTER + vmath.vector3(100, 100, 0))
			assert_xy(world, camera_pos.x + 100, camera_pos.y + 100)
		end)

		it("should provide display size", function()
			create_camera()
			local w,h = camera.get_display_size()
			assert(w == WIDTH)
			assert(h == HEIGHT)
		end)

		it("should provide window size", function()
			create_camera()
			local w,h = camera.get_window_size()
			local ratio = HIGHDPI and 2 or 1
			assert(w == WIDTH * ratio)
			assert(h == HEIGHT * ratio)
		end)

		it("should convert from world to screen coordinates", function()
			create_camera()
			
			local screen = camera.world_to_screen(camera_id, vmath.vector3(0, 0, 0))
			assert_xy(screen, 0, 0)
			screen = camera.world_to_screen(camera_id, vmath.vector3(100, 100, 0))
			local ratio = HIGHDPI and 2 or 1
			assert_xy(screen, 100 * ratio, 100 * ratio)

			camera.use_projector(camera_id, camera.PROJECTOR.FIXED_ZOOM)
			camera.set_zoom(camera_id, 2)
			wait(0.1)
			screen = camera.world_to_screen(camera_id, vmath.vector3(0, 0, 0))
			assert_xy(screen, 0, 0)
			screen = camera.world_to_screen(camera_id, vmath.vector3(100, 100, 0))
			local ratio = HIGHDPI and 2 or 1
			assert_xy(screen, 100 * ratio, 100 * ratio)
		end)
	end)
end