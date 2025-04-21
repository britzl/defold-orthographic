# defold-orthographic
Orthographic camera API for the [Defold game engine](https://www.defold.com). The API makes it super easy to convert screen to world coordinates, smoothly follow a game object and create a screen shake effect. This project is inspired by the camera component of the Phaser engine.

The project is shipped with an example that shows all the features of the orthographic camera. [Test the example app in your browser](http://britzl.github.io/Orthographic/index.html).

## Installation
You can use the orthograpic camera in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/defold-orthographic/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-orthographic/releases).

## Quick Start
Getting started with Orthographic is easy. Just add a `camera.go` to your game and configure the script properties of the `camera.script` attached to `camera.go`. The camera has the following configurable properties:

#### near_z (number) and far_z (number)
This is the near and far z-values used in the projection matrix, ie the near and far clipping plane. Anything with a z-value inside this range will be drawn by the render script.

#### zoom (number)
This is the zoom level of the camera. Modify it by calling `camera.set_zoom()`, `go.set(camera, "zoom", zoom)` or `go.animate(camera, "zoom", ...)`. Read it using `camera.get_zoom()` or `go.get(camera_id, "zoom")`.

Note that when using `go.animate()`, `go.get()` and `go.set()` you need to make sure to specify the URL to the actual camera script and not to the camera game object:

* `go.animate("mycamera#camerascript", "zoom", ...)`
* `go.set("mycamera#camerascript", "zoom")`
* `go.get("mycamera#camerascript", "zoom")`

#### auto_zoom (boolean)
Check this property if you wish the camera to automatically adjust the zoom to fit the area covered by the display width and height defined in game.project on the screen regardless of actual physical screen resolution. This means that the camera will zoom out when the content is viewed on a screen with a lower resolution, and zoom in when the content is viewed on a higher resolution screen.

#### order (number)
This value is used to sort the cameras in the list returned by `camera.get_cameras()`, from low to high values. In a multi-camera scenario the order can be used to control which camera to render first. This is for instance used in `orthographic/render/orthographic.render_script`.

#### enabled (boolean)
This controls if the camera is enabled by default or not. Send `enable` and `disable` messages to the script or use `go.set(id, "enable", true|false)` to toggle this value.

#### follow (boolean)
This controls if the camera should follow a target or not. See `camera.follow()` for details.

#### follow_horizontal (boolean)
This controls if the camera should follow the target along the horizontal axis or not. See `camera.follow()` for details.

#### follow_vertical (boolean)
This controls if the camera should follow the target along the vertical axis or not. See `camera.follow()` for details.

#### follow_immediately (boolean)
This controls if the camera should immediately position itself on the follow target when initialized or if it should apply lerp (see below). See `camera.follow()` for details.

#### follow_target (hash)
Id of the game object to follow. See `camera.follow()` for details.

#### follow_lerp (number)
Amount of lerp when following a target. See `camera.follow()` for details.

#### follow_offset (vector3)
Camera offset from the position of the followed target. See `camera.follow()` for details.

#### bounds_left (number), bounds_right (number), bounds_top (number), bounds_bottom (number)
The camera bounds. See `camera.bounds()` for details.

#### deadzone_left (number), deadzone_right (number), deadzone_top (number), deadzone_bottom (number)
The camera deadzone. See `camera.deadzone()` for details.

#### viewport_left (number), viewport_right (number), viewport_top (number), viewport_bottom (number)
The camera viewport.


### Using multiple cameras or custom viewports
The default render script will always only render a single camera with a viewport covering the entire screen. In order to use multiple cameras or render the camera using a custom viewport you need to modify the render script or use the render script included in `orthographic/render/orthographic.render_script`


## Window vs Screen coordinates
The camera API allows you to convert to and from world coordinates. This is useful when positioning a game object at the position of the mouse or knowing where in a game world a mouse click was made. The API supports conversion from both window and screen coordinates.

### Screen coordinates
This refers to the actual mouse pixel position within the window, scaled to the display size specified in game.project. These are the values from `action.x` and `action.y` in `on_input()`.

### Window coordinates
This refers to the actual mouse pixel position within the window. These are the values from `action.screen_x` and `action.screen_y` in `on_input()`. Window coordinates should be provided as is, without compensation for High DPI (this will be done automatically).


## The Orthographic Camera API - functions
The API can be used in two ways:

1. Calling functions on the `camera.lua` module
2. Sending messages to the `camera.script`



### camera.get_view(camera_id)
Get the current view of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `view` (matrix) The current view

### camera.get_viewport(camera_id)
Get the current viewport of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `x` (number) The viewport left position
* `y` (number) The viewport bottom position
* `w` (number) The viewport width
* `h` (number) The viewport height

### camera.get_projection(camera_id)
Get the current projection of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `projection` (matrix) The current projection

---

### camera.shake(camera_id, [intensity], [duration], [direction], [cb])
Shake the camera.

**PARAMETERS**
* `camera_id` (hash|url)
* `intensity` (number) - Intensity of the shake, in percent of screen. Defaults to 0.05
* `duration` (number) - Duration of the shake, in seconds. Defaults to 0.5
* `direction` (hash) - Direction of the shake. Possible values: `both`, `horizontal`, `vertical`. Defaults to `both`.
* `cb` (function) - Function to call when the shake has finished. Optional.

### camera.stop_shaking(camera_id)
Stop shaking the camera.

**PARAMETERS**
* `camera_id` (hash|url)

### camera.recoil(camera_id, offset, [duration])
Apply a recoil effect to the camera. The recoil will decay using linear interpolation.

**PARAMETERS**
* `camera_id` (hash|url)
* `offset` (vector3) - Offset to apply to the camera. Defaults to 0.05
* `duration` (number) - Duration of the recoil, in seconds. Defaults to 0.5

### camera.get_offset(camera_id)
Get the current offset of the camera (caused by shake or recoil)

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `offset` (vector3) The current offset of the camera

---

### camera.get_zoom(camera_id)
Get the current zoom level of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `zoom` (number) The current zoom of the camera


### camera.set_zoom(camera_id, zoom)
Change the zoom level of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `zoom` (number) The new zoom level of the camera


### camera.get_automatic_zoom(camera_id)
Get if the camera is configured to use automatic zoom level.

**RETURN**
* `auto_zoom` (boolean) True if automatic zoom is enabled


### camera.set_automatic_zoom(camera_id, enabled)
Set if the camera should use automatic zoom level.

**PARAM**
* `enabled` (boolean) True if automatic zoom should be enabled

---

### camera.follow(camera_id, target, [options])
Follow a game object.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `target` (hash|url) - Game object to follow
* `options` (table) - Options (see below)

Acceptable values for the `options` table:

* `lerp` (number) - Lerp from current position to target position with `lerp` as t.
* `offset` (vector3) - Camera offset from target position.
* `horizontal` (boolean) - True if following the target along the horizontal axis.
* `vertical` (boolean) - True if following the target along the vertical axis.
* `immediate` (boolean) - True if the camera should be immediately positioned on the target even when lerping.


### camera.follow_offset(camera_id, offset)
Change the camera follow offset.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `offset` (vector3) - Camera offset from target position.


### camera.unfollow(camera_id)
Stop following a game object.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

---

### camera.deadzone(camera_id, left, top, right, bottom)
If following a game object this will add a deadzone around the camera position where the camera position will not update. If the target moves to the edge of the deadzone the camera will start to follow until the target returns within the bounds of the deadzone.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `left` (number) - Number of pixels to the left of the camera
* `top` (number) - Number of pixels above the camera
* `right` (number) - Number of pixels to the right of the camera
* `bottom` (number) - Number of pixels below the camera


### camera.bounds(camera_id, left, top, right, bottom)
Limits the camera position to within the specified rectangle.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `left` (number) - Left edge of the camera bounds
* `top` (number) - Top edge of camera bounds
* `right` (number) - Right edge of camera bounds
* `bottom` (number) - Bottom edge of camera bounds

---

### camera.screen_to_world(camera_id, screen)
Translate [screen coordinates](#screen-coordinates) to world coordinates, based on the view and projection of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `screen` (vector3) Screen coordinates to convert

**RETURN**
* `world_coords` (vector3) World coordinates


### camera.window_to_world(camera_id, window)
Translate [window coordinates](#window-coordinates) to world coordinates, based on the view and projection of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera
* `window` (vector3) Window coordinates to convert

**RETURN**
* `world_coords` (vector3) World coordinates


### camera.screen_to_world_bounds(camera_id)
Translate [screen boundaries](#screen-coordinates) (corners) to world coordinates, based on the view and projection of the camera.

**PARAMETERS**
* `camera_id` (hash|url|nil) nil for the first camera

**RETURN**
* `bounds` (vector4) Screen bounds (x = left, y = top, z = right, w = bottom)


### camera.world_to_screen(camera_id, world, [adjust_mode])
Translate world coordinates to [screen coordinates](#screen-coordinates), based on the view and projection of the camera, optionally taking into account an adjust mode. This is useful when manually culling game objects and you need to determine if a world coordinate will be visible or not. It can also be used to position gui nodes on top of game objects.

**PARAMETER**
* `camera_id` (hash|url|nil) nil for the first camera
* `world` (vector3) World coordinates to convert
* `adjust_mode` (number) One of gui.ADJUST_FIT, gui.ADJUST_ZOOM and gui.ADJUST_STRETCH, or nil to not take into account the adjust mode.

**RETURN**
* `screen_coords` (vector3) Screen coordinates

### camera.world_to_window(camera_id, world)
Translate world coordinates to [window coordinates](#window-coordinates), based on the view and projection of the camera. 

**PARAMETER**
* `camera_id` (hash|url|nil) nil for the first camera
* `world` (vector3) World coordinates to convert

**RETURN**
* `window_coords` (vector3) Window coordinates


### camera.unproject(view, projection, screen)
Translate [screen coordinates](#screen-coordinates) to world coordinates using the specified view and projection.

**PARAMETERS**
* `view` (matrix4)
* `projection` (matrix4)
* `screen` (vector3) Screen coordinates to convert

**RETURN**
* `world_coords` (vector3) Note: Same v3 object as passed in as argument


### camera.project(view, projection, world)
Translate world coordinates to [screen coordinates](#screen-coordinates) using the specified view and projection.

**PARAMETERS**
* `view` (matrix4)
* `projection` (matrix4)
* `world` (vector3) World coordinates to convert

**RETURN**
* `screen_coords` (vector3) Note: Same v3 object as passed in as argument

---

### camera.get_window_size()
Get the current window size. The default values will be the ones specified in game.project.

**RETURN**
* `width` (number) - Current window width.
* `height` (number) - Current window height.


### camera.get_display_size()
Get the display size, as specified in game.project.

**RETURN**
* `width` (number) - Display width.
* `height` (number) - Display height.

---

## The Orthographic Camera API - messages
Most of the functions of the API have message equivalents that can be sent to the camera component.

### shake
Message equivalent to `camera.shake()`. Accepted message keys: `intensity`, `duration` and `direction`.

	msg.post("camera", "shake", { intensity = 0.05, duration = 2.5, direction = "both" })

### stop_shaking
Message equivalent to `camera.stop_shaking()`.

	msg.post("camera", "stop_shaking")

### recoil
Message equivalent to `camera.recoil()`. Accepted message keys: `offset` and `duration`.

	msg.post("camera", "recoil", { offset = vmath.vector3(100, 100, 0), duration = 0.75 })

### shake_complete
Message sent back to the sender of a `shake` message when the shake has completed.

### follow
Message equivalent to `camera.follow()`. Accepted message keys: `target`, `lerp`, `horizontal`, `vertical`, `immediate`, `offset`.

	msg.post("camera", "follow", { target = hash("player"), lerp = 0.7, horizontal = true, vertical = false, immediate = true })

### follow_offset
Message equivalent to `camera.follow_offset()`. Accepted message keys: `offset`.

	msg.post("camera", "follow_offset", { offset = vmath.vector3(150, 250, 0) })

### unfollow
Message equivalent to `camera.unfollow()`.

	msg.post("camera", "unfollow")

### deadzone
Message equivalent to `camera.deadzone()`. Accepted message keys: `left`, `right`, `bottom` and `top`.

	msg.post("camera", "deadzone", { left = 10, right = 200, bottom = 10, top = 100 })

### bounds
Message equivalent to `camera.bounds()`. Accepted message keys: `left`, `right`, `bottom` and `top`.

	msg.post("camera", "bounds", { left = 10, right = 200, bottom = 10, top = 100 })

### zoom_to
Message equivalent to `camera.zoom_to()`. Accepted message keys: `zoom`.

	msg.post("camera", "zoom_to", { zoom = 2.5 })

### set_automatic_zoom
Message equivalent to `camera.set_automatic_zoom()`. Accepted message keys: `enabled`.

	msg.post("camera", "set_automatic_zoom", { enabled = true })

### enable
Enable the camera. While the camera is enabled it will update it's view and projection and send these to the render script.

	msg.post("camera", "enable")

### disable
Disable the camera.

	msg.post("camera", "disable")

### use_projection
Set which projection to use.

	msg.post("camera", "use_projection", { projection = hash("FIXED_AUTO") })
