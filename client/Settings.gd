extends Node

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
var fullscreen = true

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
    var world_environment = node.get_node('WorldEnvironment')
    
    if self.gi_quality == self.GIQuality.HIGH:
        ProjectSettings["rendering/quality/voxel_cone_tracing/high_quality"] = true
    elif self.gi_quality == self.GIQuality.LOW:
        ProjectSettings["rendering/quality/voxel_cone_tracing/high_quality"] = false
    else:
        node.get_node('GIProbe').hide()
        node.get_node('ReflectionProbe').show()

    if self.aa_quality == self.AAQuality.AA_8X:
        get_viewport().msaa = Viewport.MSAA_8X
    elif self.aa_quality == self.AAQuality.AA_4X:
        get_viewport().msaa = Viewport.MSAA_4X
    elif self.aa_quality == self.AAQuality.AA_2X:
        get_viewport().msaa = Viewport.MSAA_2X
    else:
        get_viewport().msaa = Viewport.MSAA_DISABLED
        
    if self.ssao_quality == self.SSAOQuality.HIGH:
        world_environment.environment.ssao_enabled = true
        world_environment.environment.ssao_quality = world_environment.environment.SSAO_QUALITY_HIGH
    elif self.ssao_quality == self.SSAOQuality.LOW:
        world_environment.environment.ssao_enabled = true
        world_environment.environment.ssao_quality = world_environment.environment.SSAO_QUALITY_LOW
    else:
        world_environment.environment.ssao_enabled = false

    if self.bloom_quality == self.BloomQuality.HIGH:
        world_environment.environment.glow_enabled = true
        world_environment.environment.glow_bicubic_upscale = true
    elif self.bloom_quality == self.BloomQuality.LOW:
        world_environment.environment.glow_enabled = true
        world_environment.environment.glow_bicubic_upscale = false
    else:
        world_environment.environment.glow_enabled = false
        world_environment.environment.glow_bicubic_upscale = false

    var window_size = OS.window_size
    if self.resolution == self.Resolution.NATIVE:
        pass
    elif self.resolution == self.Resolution.RES_1080:
        var minsize = Vector2(window_size.x * 1080 / window_size.y, 1080.0)
        get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP_HEIGHT, minsize)
    elif self.resolution == self.Resolution.RES_720:
        var minsize = Vector2(window_size.x * 720 / window_size.y, 720.0)
        get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP_HEIGHT, minsize)
    elif self.resolution == self.Resolution.RES_540:
        var minsize = Vector2(window_size.x * 540 / window_size.y, 540.0)
        get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP_HEIGHT, minsize)        
