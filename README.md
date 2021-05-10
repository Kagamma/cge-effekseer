This repository is an experimental effort attempt at integrating Effekseer into Castle Game Engine.

### Precompiled dynamic library
For lazy people ;). This contains binaries for win32, win64 and android, built with -O3 optimization : https://drive.google.com/file/d/1trF_9hx55ajKUVSv4X3AF3fQBZcGWj28/view?usp=sharing

### How to use

Import `CastleEffekseer.pas`, `effekseer.pas` and corresponding binaries into your project.  Add `CastleEffekseer` unit in your code. The unit contains `TCastleEffekseer`, which is descendant of `TCastleSceneCore`, you can use it to load effects like how you normally load model with `TCastleScene`.

```delphi
Effect := TCastleEffekseer.Create(Application);
Effect.Loop := False; // Do not loop the effect
Effect.ReleaseWhenDone := True; // Automatically free Effect when it's done playing
Effect.URL := 'castle-data:/effect/smoke.efk';
Viewport.Items.Add(Effect);
```

Global variables that can be set in `initialization` block:

-   `EfkMaximumNumberOfInstances`: Maximum number of emitter instances, default is 1024
-   `EfkMaximumNumberOfSquares`: Maximum number of particles, default is 16384 for desktop, and 8192 for mobile platform.
-   `EfkDesktopRenderBackend`: Desktop render backend, default is OpenGL 2.
-   `EfkMobileRenderBackend`: Mobile render backend, default is OpenGL ES2.
-   `EfkUseCGEImageLoader`: Use Castle Game Engine's TCastleImage to load images, default is True. If set to False then it will use stb as loader.

It's also integrate in the editor. You can put `CastleEffekseer` in editor_units in your `CastleEngineManifest.xml`, and it will register new component `Effkseer Emitter`.

### Generate dynamic library guidelines
This section is for people who want to build Effekseer dynamic library. I am not really good at cmake, and this is written with Windows and cmake-gui in mind.

###### Obtain Effekser official runtime
There are 2 ways to do it:
- Download [Effekseer for Runtime](https://effekseer.github.io/en/download.html "Effekseer for Runtime") directly from website. This is what I did, and the following guidelines will be based on this method.
- Clone it from https://github.com/effekseer/Effekseer. This contains both runtime and editor.

###### Patch for MinGW (skip if you use Visual Studio or GCC)
Replace all `posix_` usages in runtime source code with cross-platform alternative (there are 3 places where this is used).

###### Generate makefiles
You need to copy `wrapper` from this repo and put it in Effekseer runtime's root directory.
Add these lines to Effekseer runtime's root CMakeLists.txt:

    option(BUILD_WRAPPER "Build wrapper" ON)
    if (BUILD_WRAPPER)
        add_subdirectory(wrapper)
    endif()
Generate makefiles, remember to enable `BUILD_WRAPPER`, `BUILD_SHARED_LIBS`, `USE_OPENGL3` (for desktop), `USE_OPENGLES2` (for mobile platform). The rest of the flags can be disabled.
Make sure to include necessary libraries in `CMAKE_CXX_STANDARD_LIBRARIES`, for example:
- Windows: `-lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 -lopengl32 -lglu32 -lwinpthread`
- Android: `-latomic -lm -landroid -lEGL -lGLESv2`

For Linux, need to add `-fPIC` flag to `CMAKE_CXX_FLAGS`.

If everything build successfully, the result library can be found in `wrapper` directory.

### Things that doesn't work
- Sound: I don't plan on including Sound support at the moment.
