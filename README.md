# defold-orthographic
Orthographic camera functionality for the Defold game engine. This project is inspired by the camera component of the Phaser engine.

## Installation
You can use the orthograpic camera in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/defold-orthographic/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-orthographic/releases).

## Basic usage
Add the ```camera.go``` to a collection. Depending on your use case you can either add the camera as a child of a game object to have the camera always follow that object or you could add the camera as a root game object and move or animate it manually using code or using the Orthographic Camera API (see below).

The camera will send view projection messages to the render script while it is enabled. Make sure your render script handles this message! See below for details.

## Configuration
Select the script component attached to the ```camera.go``` to modify the properties. The camera has the following configurable properties:

#### near_z (number) and far_z (number)
This is the near and far z-values used in the projection matrix, ie the near and far clipping plane. Anything with a z-value inside this range will be drawn by the render script.

#### projection (hash)
The camera supports different kinds of orthographic projections:

* DEFAULT - The camera will use the default projection matrix where aspect ratio isn't maintained and content is stretched/shrunk when the window is resized.
* FIXED - The camera will use a fixed projection where the aspect ratio is maintained and additional content will be visible if the aspect ratio differs from the width/height ratio from game.project.

Additional custom projections can be added. See ```camera.add_projector()``` below.

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

## The Orthographic Camera API
The API can be used in two ways:

1. Calling functions on the camera.lua module
2. Sending messages to the camera.script

### camera.shake(camera_id, intensity, duration, direction, cb)
Shake the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```intensity``` (number) - Intensity of the shake, in percent of screen. Defaults to 0.05
* ```duration``` (number) - Duration of the shake, in seconds. Defaults to 0.5
* ```direction``` (hash) - Direction of the shake. Possible values: ```both```, ```horizontal```, ```vertical```. Defaults to ```both```.
* ```cb``` (function) - Function to call when the shake has finished. Optional.

### camera.follow(camera_id, target, lerp)
Follow a game object.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```target``` (hash|url) - Game object to follow
* ```lerp``` (number) - Lerp from current position to target position with ```lerp``` as t. Optional.

### camera.unfollow(camera_id)
Stop following a game object.

**PARAMETERS**
* ```camera_id``` (hash|url)

### camera.deadzone(camera_id, left, right, bottom, top)
If following a game object this will add a deadzone around the camera position where the camera position will not update. If the target moves to the edge of the deadzone the camera will start to follow until the target returns within the bounds of the deadzone.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```left``` (number) - Number of pixels to the left of the camera
* ```right``` (number) - Number of pixels to the right of the camera
* ```bottom``` (number) - Number of pixels below the camera
* ```top``` (number) - Number of pixels above the camera

### camera.sceen_to_world(camera_id, x, y, [z])
Convert screen coordinates to world coordinates, based on the projection of the camera.

**PARAMETERS**
* ```camera_id``` (hash|url)
* ```x``` (number) Screen x
* ```y``` (number) Screen y
* ```z``` (number) Optional z-value to assign to the world coordinates

**RETURN**
* ```world_coords``` (vector3)

### camera.add_projector(projector_id, projector_fn)
Add a custom projector that can be used by cameras in your project (see configuration above).

**PARAMETERS**
* ```projector_id``` (hash) - Id of the projector. Used as a value in the ```projection``` field of the camera script.
* ```projector_fn``` (function) - The function to call when a projection matrix is needed for the camera. The function will receive the id, near_z and far_z values of the camera.

### shake
Message equivalent to ```camera.shake()```. Supports ```intensity```, ```duration``` and ```direction```.

### shake_complete
Message sent back to the sender of a ```shake``` message when the shake has completed.

### follow
Message equivalent to ```camera.follow()```. Supports ```target``` and ```lerp```.

### unfollow
Message equivalent to ```camera.unfollow()```.

### deadzone
Message equivalent to ```camera.deadzone()```. Supports ```left```, ```right```, ```bottom```, ```top```.

### enable
Enable the camera. While the camera is enabled it will update it's view and projection and send these to the render script.

### disable
Disable the camera.

## License
This library is released under the same [Terms and Conditions as Defold](http://www.defold.com/about-terms/).
