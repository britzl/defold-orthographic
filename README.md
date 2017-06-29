# defold-orthographic
Orthographic camera functionality for the Defold game engine

## Installation
You can use the orthograpic camera in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/defold-orthographic/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-orthographic/releases).

## Basic usage
Add the ```camera.go``` to a collection. Depending on your use case you can either add the camera as a child of a game object to have the camera follow that object or you could add the camera as a root game object and move or animate it manually using code. The camera will send view projection messages to the render script while it is enabled. Make sure your render script handles this message! See below for details.

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
While the camera is enabled it will send ```set_view_projection``` messages once per frame to the render script. The message is the same as that of the camera component, meaning that it contains ```id```, ```view``` and ```projection``` values. Make sure that these values are handled and used properly:

	function on_message(self, message_id, message, sender)
		if message_id == hash("set_view_projection") then
			self.camera_id = message.id
			self.view = message.view
			self.projection = message.projection
		end

And in your update() function:

	function update(self)
		render.set_view(self.view)
		render.set_projection(self.projection)
		-- draw using the view and projection

An alternative approach is to ignore the set_view_projection message and directly read the view and projection from the camera in the render script:

	local camera = require "orthographic.camera"

	function update(self)
		local camera_id = id of your camera
		render.set_view(camera.get_view(camera_id))
		render.set_projection(camera.get_projection(camera_id))
		-- draw using the view and projection

## The Orthographic Camera API

#### camera.sceen_to_world(camera_id, x, y, [z])
Convert screen coordinates to world coordinates, based on the projection of the camera.

#### camera.add_projector(projector_id, projector_fn)
Add a custom projector that can be used by camera.

projector_id (hash) - Id of the projector. Used as a value in the ```projection``` field of the camera script.

projector_fn - The function to call when a projection matrix is needed for the camera. The function will receive the id, near_z and far_z values of the camera.


## License
This library is released under the same [Terms and Conditions as Defold](http://www.defold.com/about-terms/).
