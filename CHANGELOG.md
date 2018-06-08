## Orthographic Camera API 2.2.5 [britzl released 2018-04-16]
FIX: Assign default `display.width` and `display.height` (960x640) if none is provided from game.project

## Orthographic Camera API 2.2.4 [britzl released 2018-04-08]
FIX: An enabled camera is now immediately updated on creation. This will make sure that the render script gets the correct view and projection without any delay.

## Orthographic Camera API 2.2.3 [britzl released 2018-04-01]
FIX: Added missing message constant that made the camera.set_projection() function fail

## Orthographic Camera API 2.2.2 [britzl released 2018-03-31]
FIX: camera.set_zoom() crash

## Orthographic Camera API 2.2.1 [britzl released 2018-03-19]
FIX: Added check on script shared state in the provided render script. Also added a note on this in the readme

## Orthographic Camera API 2.2 [britzl released 2018-02-17]
NEW: Camera script properties to control bounds, deadzone, follow  
CHANGE: Camera script properties can now be manipulated using go.animate(), go.set() and go.get()

## Orthographic Camera API 2.1 [britzl released 2018-02-17]
NEW: camera.recoil()

## Orthographic Camera API 2.0 [britzl released 2018-02-17]
NEW: Camera zoom property. This makes it a whole lot easier to at run-time configure the zoom level of a camera  
NEW: camera.get_zoom() and camera.zoom_to()  
CHANGE: The available projections have been simplified. There's now only FIXED_AUTO and FIXED_ZOOM.  
  
Refer to the example project to see the new changes in action.

## Orthographic Camera API 1.5 [britzl released 2018-02-04]
NEW: Added camera.stop_shaking()

## Orthographic Camera API 1.4.2 [britzl released 2018-01-11]
FIX: Added argument asserts to all public facing functions on camera.lua

## Orthographic Camera API 1.4.1 [britzl released 2017-12-15]
FIX: Set an initial view and projection on the camera when it is initialized

## Orthographic Camera API 1.4 [britzl released 2017-12-15]
NEW: screen_to_world_bounds()

## Orthographic Camera API 1.3 [britzl released 2017-12-14]
NEW: camera.use_projector() to change projector at runtime  
NEW: camera.set_window_size() to feed current window size from render script to camera  
NEW: camera.get_window_size() to get current window size  
NEW: camera.get_display_size() to get display size from game.project  
NEW: camera.PROJECTORS.* constants for the provided projectors  
CHANGE: Moved projector functions from render script to camera.lua  


## Orthographic Camera API 1.2.2 [britzl released 2017-08-26]
* CHANGE: Moved the render script from the example project into the library folder.

## Orthographic Camera API 1.2.1 [britzl released 2017-08-03]
FIX: Bounds still didn't work as expected

## Orthographic Camera API 1.2 [britzl released 2017-08-01]
Delayed camera update to after all game objects have been update. This is to ensure that camera bounds are respected properly.

## Orthographic Camera API 1.1 [britzl released 2017-07-26]
* Fixed issues with the new bounds functionality  
* Added more projections (FIXED_NOZOOM, FIXED_ZOOM_2, FIXED_ZOOM_4, FIXED_ZOOM_6, FIXED_ZOOM_8 and FIXED_ZOOM_10)

## Orthographic Camera API 1.0 [britzl released 2017-07-24]
First official release of the Orthographic Camera API

## Orthographic Camera API 1.0 beta [britzl released 2017-06-30]
First public beta version of the API

