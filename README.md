# defold-orthographic
Orthographic camera API for the [Defold game engine](https://www.defold.com). The API makes it super easy to convert screen to world coordinates, smoothly follow a game object and create a screen shake effect. This project is inspired by the camera component of the Phaser engine.

The project is shipped with an example that shows all the features of the orthographic camera. [Test the example app in your browser](http://britzl.github.io/publicexamples/orthographic/index.html).

## Installation
You can use the orthograpic camera in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/defold-orthographic/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-orthographic/releases).

## Basic usage
Add the ```camera.go``` to a collection. Depending on your use case you can either add the camera as a child of a game object to have the camera always follow that object or you could add the camera as a root game object and move or animate it manually using code or using the Orthographic Camera API (see below).

The camera will send view projection messages to the render script while it is enabled. Make sure your render script handles this message! See the section on render script integration below.

## Configuration
Select the script component attached to the ```camera.go``` to modify the properties. The camera has the following configurable properties:

#### near_z (number) and far_z (number)
This is the near and far z-values used in the projection matrix, ie the near and far clipping plane. Anything with a z-value inside this range will be drawn by the render script.

#### zoom (number)
This is the zoom level of the camera. Modify it by calling ```camera.zoom_to()```. Read it using ```camera.get_zoom()``` or using ```go.get(camera_id, "zoom")```.

#### projection (hash)
The camera can be configured to support different kinds of orthographic projections. The default projection (aptly named ```DEFAULT```) uses the same orthographic projection matrix as in the default render script (ie aspect ratio isn't maintained and content is stretched). Other projections are available out-of-the box:

* ```FIXED_AUTO``` - A fixed aspect ratio projection that automatically zooms in/out to fit the original viewport contents regardless of window size.
* ```FIXED_ZOOM``` - A fixed aspect ratio projection with zoom.

Note: For the above projections to work you need to pass the window dimensions from your render script to the camera. See [the section on render script integration](#render_script_integration).

Additional custom projections can be added, see ```camera.add_projector()``` below.

#### enabled (boolean)
This controls if the camera is enabled by default or not. Send ```enable``` and ```disable``` messages to the script or use ```go.set(id, "enable", true|false)``` to toggle this value.

## Render script integration
While the camera is enabled it will send ```set_view_projection``` messages once per frame to the render script. The message is the same as that of the camera component, meaning that it contains ```id```, ```view``` and ```projection``` values. Make sure that these values are handled and used properly in the render script:

	function update(self)
		...
		render.set_view(self.view)
		render.set_projection(self.projection)
		-- draw using the view and projection
		...
	end

	function on_message(self, message_id, message, sender)
		if message_id == hash("set_view_projection") then
			self.camera_id = message.id
			self.view = message.view
			self.projection = message.projection
		end
	end

An alternative approach is to ignore the ```set_view_projection``` message and directly read the view and projection from the camera in the render script:

	local camera = require "orthographic.camera"

	function update(self)
		...
		local camera_id = id of your camera
		render.set_view(camera.get_view(camera_id))
		render.set_projection(camera.get_projection(camera_id))
		-- draw using the view and projection
		...
	end

### Feeding window size to the camera
It is recommended to send the window width and height from the render script to the camera module. This is required if any of the projectors provided in ```camera.lua``` is used. It also allows custom projectors to get the current window size by calling ```camera.get_window_size()```. Set the window size like this:

	local camera = require "orthographic.camera"

	function update(self)
		...
		local window_width = render.get_window_width()
		local window_height = render.get_window_height()
		camera.set_window_size(window_width, window_height)
		...
	end

### Example render script
The orthographic/render folder contains a render script that does the above mentioned integration of the Orthographic Camera API. Use it as it is or copy it into your project and make whatever modifications that you need.

## The Orthographic Camera API - functions
The API can be used in two ways:

1. Calling functions on the ```camera.lua``` module
2. Sending messages to the ```camera.script```

### camera.shake(camera_id, [intensity], [duration], [direction], [cb])
Shake the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```intensity``` (number) - Intensity of the shake, in percent of screen. Defaults to 0.05
* ```duration``` (number) - Duration of the shake, in seconds. Defaults to 0.5
* ```direction``` (hash) - Direction of the shake. Possible values: ```both```, ```horizontal```, ```vertical```. Defaults to ```both```.
* ```cb``` (function) - Function to call when the shake has finished. Optional.


### camera.stop_shaking(camera_id)
Stop shaking the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)


### camera.recoil(camera_id, offset, [duration])
Apply a recoil effect to the camera. The recoil will decay using linear interpolation.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```offset``` (vector3) - Offset to apply to the camera. Defaults to 0.05
* ```duration``` (number) - Duration of the recoil, in seconds. Defaults to 0.5


### camera.get_zoom(camera_id)
Get the current zoom level of the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)

**RETURN**
* ```zoom``` (number) The current zoom of the camera


### camera.zoom_to(camera_id, zoom)
Change the zoom level of the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```zoom``` (number) The new zoom level of the camera


### camera.follow(camera_id, target, [lerp])
Follow a game object.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```target``` (hash|url) - Game object to follow
* ```lerp``` (number) - Lerp from current position to target position with ```lerp``` as t. Optional.

### camera.unfollow(camera_id)
Stop following a game object.

**PARAMETERS**
* ```camera_id``` (hash|url)

### camera.deadzone(camera_id, left, top, right, bottom)
If following a game object this will add a deadzone around the camera position where the camera position will not update. If the target moves to the edge of the deadzone the camera will start to follow until the target returns within the bounds of the deadzone.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```left``` (number) - Number of pixels to the left of the camera
* ```top``` (number) - Number of pixels above the camera
* ```right``` (number) - Number of pixels to the right of the camera
* ```bottom``` (number) - Number of pixels below the camera

### camera.bounds(camera_id, left, top, right, bottom)
Limits the camera position to within the specified rectangle.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```left``` (number) - Left edge of the camera bounds
* ```top``` (number) - Top edge of camera bounds
* ```right``` (number) - Right edge of camera bounds
* ```bottom``` (number) - Bottom edge of camera bounds


### camera.screen_to_world(camera_id, screen)
Translate screen coordinates to world coordinates, based on the view and projection of the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```screen``` (vector3) Screen coordinates to convert

**RETURN**
* ```world_coords``` (vector3) World coordinates


### camera.screen_to_world_bounds(camera_id)
Translate screen boundaries (corners) to world coordinates, based on the view and projection of the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)

**RETURN**
* ```bounds``` (vector4) Screen bounds (x = left, y = top, z = right, w = bottom)


### camera.world_to_screen(camera_id, world)
Translate world coordinates to screen coordinates, based on the view and projection of the camera. This is useful when manually culling game objects and you need to determine if a world coordinate will be visible or not.

**PARAMETER**
* ```camera_id``` (hash|url)
* ```world``` (vector3) World coordinates to convert

**RETURN**
* ```screen_coords``` (vector3) Screen coordinates


### camera.unproject(view, projection, screen)
Translate screen coordinates to world coordinates using the specified view and projection.

**PARAMETERS**
* ```view``` (matrix4)
* ```projection``` (matrix4)
* ```screen``` (vector3) Screen coordinates to convert

**RETURN**
* ```world_coords``` (vector3) Note: Same v3 object as passed in as argument


### camera.project(view, projection, world)
Translate world coordinates to screen coordinates using the specified view and projection.

**PARAMETERS**
* ```view``` (matrix4)
* ```projection``` (matrix4)
* ```world``` (vector3) World coordinates to convert

**RETURN**
* ```screen_coords``` (vector3) Note: Same v3 object as passed in as argument


### camera.add_projector(projector_id, projector_fn)
Add a custom projector that can be used by cameras in your project (see configuration above).

**PARAMETERS**
* ```projector_id``` (hash) - Id of the projector. Used as a value in the ```projection``` field of the camera script.
* ```projector_fn``` (function) - The function to call when a projection matrix is needed for the camera. The function will receive the id, near_z and far_z values of the camera.


### camera.use_projector(camera_id, projector_id)
Set a specific projector for a camera. This must be either one of the predefined projectors (see above) or a custom projector added using ```camera.add_projector()```.

**PARAMETERS**
* ```camera_id``` (hash) - Id of the camera to set projector for.
* ```projector_id``` (hash) - Id of the projector.


### camera.set_window_size(width, height)
Set the current window size so that it is available to projectors via ```camera.get_window_size()```. Set this via your render script.

**PARAMETERS**
* ```width``` (number) - Current window width.
* ```height``` (number) - Current window height.


### camera.get_window_size()
Get the current window size, as it was provided by ```camera.set_window_size()```. The default values will be the ones specified in game.project.

**RETURN**
* ```width``` (number) - Current window width.
* ```height``` (number) - Current window height.


### camera.get_display_size()
Get the display size, as specified in game.project.

**RETURN**
* ```width``` (number) - Display width.
* ```height``` (number) - Display height.

## The Orthographic Camera API - messages
Most of the functions of the API have message equivalents that can be sent to the camera component.

### shake
Message equivalent to ```camera.shake()```. Accepted message keys: ```intensity```, ```duration``` and ```direction```.

	msg.post("camera", "shake", { intensity = 0.05, duration = 2.5, direction = "both" })

### stop_shaking
Message equivalent to ```camera.stop_shaking()```.

	msg.post("camera", "stop_shaking")

### recoil
Message equivalent to ```camera.recoil()```. Accepted message keys: ```offset``` and ```duration```.

	msg.post("camera", "recoil", { offset = vmath.vector3(100, 100, 0), duration = 0.75 })

### shake_complete
Message sent back to the sender of a ```shake``` message when the shake has completed.

### follow
Message equivalent to ```camera.follow()```. Accepted message keys: ```target``` and ```lerp```.

	msg.post("camera", "follow", { target = hash("player"), lerp = 0.7 })

### unfollow
Message equivalent to ```camera.unfollow()```.

	msg.post("camera", "unfollow")

### deadzone
Message equivalent to ```camera.deadzone()```. Accepted message keys: ```left```, ```right```, ```bottom``` and ```top```.

	msg.post("camera", "deadzone", { left = 10, right = 200, bottom = 10, top = 100 })

### bounds
Message equivalent to ```camera.bounds()```. Accepted message keys: ```left```, ```right```, ```bottom``` and ```top```.

	msg.post("camera", "bounds", { left = 10, right = 200, bottom = 10, top = 100 })

### zoom_to
Message equivalent to ```camera.zoom_to()```. Accepted message keys: ```zoom```.

	msg.post("camera", "zoom_to", { zoom = 2.5 })

### enable
Enable the camera. While the camera is enabled it will update it's view and projection and send these to the render script.

	msg.post("camera", "enable")

### disable
Disable the camera.

	msg.post("camera", "disable")
