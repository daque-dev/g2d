import derelict.sdl2.sdl : SDL_Window, SDL_Renderer, SDL_Texture;

private SDL_Window* _window;
private SDL_Renderer* _renderer;
private SDL_Texture*[] _textures;

public alias TextureId = ulong;

private TextureId _lastTexture;

public TextureId newTexture(string fileName)
{
    import derelict.sdl2.image : IMG_Load, IMG_GetError;
    import derelict.sdl2.sdl : SDL_CreateTextureFromSurface;
    import std.string : toStringz, fromStringz;
    import std.exception : enforce;
    import std.conv : text;

    enforce(_lastTexture + 1 < _textures.length);

    auto surface = IMG_Load(fileName.toStringz);
    enforce(surface !is null, text(fromStringz(IMG_GetError())));
    _textures[_lastTexture + 1] = SDL_CreateTextureFromSurface(_renderer, surface);
    _lastTexture = _lastTexture + 1;
    enforce(_textures[_lastTexture]!is null);
    return _lastTexture;
}

public void freeTexture(TextureId textureId)
{
    return;
}

struct WindowRectangle
{
    int[2] position;
    int[2] dimensions;
}

WindowRectangle worldRectangleToWindowRectangle(float[2] center, float[2] dimensions)
{
    auto upperLeftCorner = worldToWindowCoordinates([
            center[0] - dimensions[0] / 2.0f, center[1] + dimensions[1] / 2.0f
            ]);
    auto lowerRightCorner = worldToWindowCoordinates([
            center[0] + dimensions[0] / 2.0f, center[1] - dimensions[1] / 2.0f
            ]);
    int[2] rectangleSize = lowerRightCorner[] - upperLeftCorner[];
    assert(rectangleSize[0] >= 0 && rectangleSize[1] >= 0);
    return WindowRectangle(upperLeftCorner, rectangleSize);
}

public void drawTexture(float[2] center, float[2] dimensions, TextureId textureId)
{
    import derelict.sdl2.sdl : SDL_Rect, SDL_RenderCopy;

    auto windowRectangle = worldRectangleToWindowRectangle(center, dimensions);
    auto texture = _textures[textureId];
    SDL_Rect rect;
    with (rect)
    {
        x = windowRectangle.position[0];
        y = windowRectangle.position[1];
        w = windowRectangle.dimensions[0];
        h = windowRectangle.dimensions[1];
    }
    SDL_RenderCopy(_renderer, texture, null, &rect);
}

public struct InitOptions
{
    string windowName;
    uint width, height;
    bool centerWindow;
    ulong maxNoTextures;
}

public void init(InitOptions options)
{
    import std.string : toStringz;
    import derelict.sdl2.sdl : DerelictSDL2, SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_UNDEFINED, SDL_CreateWindow, SDL_WINDOW_SHOWN,
        SDL_CreateRenderer, SDL_RENDERER_ACCELERATED, SDL_Init, SDL_INIT_EVERYTHING;
    import derelict.sdl2.image : DerelictSDL2Image, IMG_Load, IMG_Init, IMG_INIT_PNG;

    DerelictSDL2.load();
    DerelictSDL2Image.load();

    SDL_Init(SDL_INIT_EVERYTHING);
    IMG_Init(IMG_INIT_PNG);

    auto windowPos = options.centerWindow ? SDL_WINDOWPOS_CENTERED : SDL_WINDOWPOS_UNDEFINED;
    _window = SDL_CreateWindow(options.windowName.toStringz, windowPos,
            windowPos, options.width, options.height, SDL_WINDOW_SHOWN);
    _renderer = SDL_CreateRenderer(_window, -1, SDL_RENDERER_ACCELERATED);
    _textures.length = options.maxNoTextures;
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

private Camera getCurrentCamera()
{
    if (_cameraGetter)
        return _cameraGetter();
    return _camera;
}

private int[2] worldToWindowCoordinates(float[2] worldCoordinates)
{
    import derelict.sdl2.sdl : SDL_GetWindowSize;

    Camera camera = getCurrentCamera;
    int[2] windowSize;
    SDL_GetWindowSize(_window, &windowSize[0], &windowSize[1]);
    float[2] windowSizeFloat = [
        cast(float) windowSize[0], cast(float) windowSize[1]
    ];
    worldCoordinates[] -= camera.center[];
    worldCoordinates[] /= camera.dimensions[];
    worldCoordinates[] *= windowSizeFloat[];
    windowSizeFloat[] /= 2.0f;
    float[2] resultFloat = [worldCoordinates[0], -worldCoordinates[1]];
    resultFloat[] += windowSizeFloat[];
    return [cast(int) resultFloat[0], cast(int) resultFloat[1]];
}

public struct Color
{
    ubyte red, green, blue;
}

public void drawRectangle(float[2] center, float[2] dimensions, Color color)
{
    import derelict.sdl2.sdl : SDL_Rect, SDL_RenderFillRect, SDL_SetRenderDrawColor;

    auto windowRectangle = worldRectangleToWindowRectangle(center, dimensions);
    SDL_Rect rect;
    with (rect)
    {
        x = windowRectangle.position[0];
        y = windowRectangle.position[1];
        w = windowRectangle.dimensions[0];
        h = windowRectangle.dimensions[1];
    }
    SDL_SetRenderDrawColor(_renderer, color.red, color.green, color.blue, ubyte(255));
    SDL_RenderFillRect(_renderer, &rect);
}

private Color _clearColor;
public void clearColor(Color c)
{
    _clearColor = c;
}

public void startDrawing()
{
    import derelict.sdl2.sdl : SDL_RenderClear, SDL_SetRenderDrawColor;

    SDL_SetRenderDrawColor(_renderer, _clearColor.red, _clearColor.green,
            _clearColor.blue, ubyte(255));
    SDL_RenderClear(_renderer);
}

public void endDrawing()
{
    import derelict.sdl2.sdl : SDL_RenderPresent;

    SDL_RenderPresent(_renderer);
}

public void draw(alias F)()
{
    startDrawing;
    F();
    endDrawing;
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
        maxNoTextures = 100;
    }
    init(initOptions);
    scope (exit)
        deinit();
    auto testTexture = newTexture("test_image.png");
    scope (exit)
        freeTexture(testTexture);
    Camera camera;
    with (camera)
    {
        center = [0, 0];
        dimensions = [100, 100];
    }

    setCamera(camera);
    import std.range : iota;

    foreach (second; iota(1, 100))
    {
        draw!({
            drawRectangle([second, 0], [10, 10], Color(255, 0, 0));
            drawTexture([second, 0], [10, 10], testTexture);
        });
        Thread.sleep(dur!"msecs"(20));
        writeln(second);
    }
    deinit();
}
