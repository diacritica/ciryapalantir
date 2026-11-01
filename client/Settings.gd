extends Node

# Graphics quality: the presets high, medium and low, applied to the game scene.
# The screen refresh paces the frames (vsync), and a window without the focus
# draws fewer, so several clients on one computer do not fight for the GPU

# Frames per second of a window without the focus, still smooth to watch
const BACKGROUND_FPS = 30

enum GIQuality {
    DISABLED = 0,
    LOW = 1,
    HIGH = 2,
}

enum AAQuality {
    DISABLED = 0,
    AA_2X = 1,
    AA_4X = 2,
    AA_8X = 3,
}

enum SSAOQuality {
    DISABLED = 0,
    LOW = 1,
    HIGH = 2,
}

enum BloomQuality {
    DISABLED = 0,
    LOW = 1,
    HIGH = 2,
}

enum Resolution {
    RES_540 = 0,
    RES_720 = 1,
    RES_1080 = 2,
    NATIVE = 3,
}

var gi_quality = GIQuality.LOW
var aa_quality = AAQuality.AA_2X
var ssao_quality = SSAOQuality.DISABLED
var bloom_quality = BloomQuality.HIGH
var resolution = Resolution.NATIVE

func _notification(what):
    match what:
        MainLoop.NOTIFICATION_WM_FOCUS_IN:
            Engine.target_fps = 0
        MainLoop.NOTIFICATION_WM_FOCUS_OUT:
            Engine.target_fps = BACKGROUND_FPS

func high():
    gi_quality = GIQuality.HIGH
    aa_quality = AAQuality.AA_4X
    ssao_quality = SSAOQuality.HIGH
    bloom_quality = BloomQuality.HIGH
    resolution = Resolution.NATIVE
    
func medium():
    gi_quality = GIQuality.LOW
    aa_quality = AAQuality.AA_2X
    ssao_quality = SSAOQuality.LOW
    bloom_quality = BloomQuality.LOW
    resolution = Resolution.RES_1080
    
func low():
    gi_quality = GIQuality.DISABLED
    aa_quality = AAQuality.DISABLED
    ssao_quality = SSAOQuality.DISABLED
    bloom_quality = BloomQuality.DISABLED
    resolution = Resolution.RES_720

func apply_settings(node):
    var environment = node.get_node("WorldEnvironment").environment

    # The scene has no GIProbe yet, so the GI quality changes nothing. Without
    # GI the reflection probe lights the table
    if gi_quality == GIQuality.DISABLED:
        var probe = node.get_node_or_null("GIProbe")
        if probe:
            probe.hide()
        node.get_node("ReflectionProbe").show()

    # AAQuality follows the order of Viewport.MSAA_*
    get_viewport().msaa = aa_quality

    environment.ssao_enabled = ssao_quality != SSAOQuality.DISABLED
    environment.ssao_quality = Environment.SSAO_QUALITY_HIGH if ssao_quality == SSAOQuality.HIGH else Environment.SSAO_QUALITY_LOW
    environment.glow_enabled = bloom_quality != BloomQuality.DISABLED
    environment.glow_bicubic_upscale = bloom_quality == BloomQuality.HIGH

    # In the browser, the near depth of field leaves the scene black in Chrome:
    # it reads the image it draws on, and Chrome's WebGL refuses that. It only
    # blurs what is very close to the camera
    if OS.has_feature("JavaScript"):
        environment.dof_blur_near_enabled = false

    if resolution != Resolution.NATIVE:
        var height = [540.0, 720.0, 1080.0][resolution]
        var size = OS.window_size
        get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP_HEIGHT, Vector2(size.x * height / size.y, height))
