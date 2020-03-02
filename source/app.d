import derelict.sdl2.sdl : SDL_Window, SDL_Renderer;

private SDL_Window* _window;
private SDL_Renderer* _renderer;

public struct InitOptions
{
    string windowName;
    uint width, height;
    bool centerWindow;
}

public void init(InitOptions options)
{
    import std.string : toStringz;
    import derelict.sdl2.sdl : DerelictSDL2, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_UNDEFINED,
        SDL_CreateWindow, SDL_WINDOW_SHOWN, SDL_CreateRenderer, SDL_RENDERER_ACCELERATED;

    DerelictSDL2.load();
    auto windowPos = options.centerWindow ? SDL_WINDOWPOS_CENTERED : SDL_WINDOWPOS_UNDEFINED;
    _window = SDL_CreateWindow(options.windowName.toStringz, windowPos,
            windowPos, options.width, options.height, SDL_WINDOW_SHOWN);
    _renderer = SDL_CreateRenderer(_window, -1, SDL_RENDERER_ACCELERATED);
    return;
}

public void deinit()
{
    import derelict.sdl2.sdl : SDL_DestroyWindow, SDL_DestroyRenderer;

    SDL_DestroyWindow(_window);
    SDL_DestroyRenderer(_renderer);
}

public struct Camera
{
    float[2] center;
    float[2] dimensions;
}

private Camera _camera;

public void setCamera(Camera camera)
{
    _camera = camera;
}

private Camera delegate() _cameraGetter;

public void setCameraGetter(Camera delegate() cameraGetter)
{
    _cameraGetter = cameraGetter;
}

unittest
{
    import core.thread : Thread;
    import core.time : dur;
    import std.stdio : writeln;

    InitOptions initOptions;
    with (initOptions)
    {
        windowName = "testing window";
        width = 800;
        height = 600;
        centerWindow = false;
    }
    init(initOptions);
    foreach (second; [1, 2, 3])
    {
        Thread.sleep(dur!"seconds"(1));
        writeln(second);
    }
    deinit();
}
