extends RefCounted
class_name BuildingSurfaceLibrary

# Deterministic, shared PBR texture maps for procedural city architecture.
# These are authored procedural materials (not photographic scans) and stay fully offline.
const TEXTURE_SIZE := 128
static var _cache: Dictionary = {}

static func surface_for_color(color: Color, hint: String = "") -> String:
	if not hint.is_empty():
		return hint
	var saturation := color.s
	var luminance := color.get_luminance()
	var hue := color.h
	if color.b > color.r * 1.16 and color.b > color.g * 0.96 and saturation > 0.18:
		return "glass"
	# Timber browns are more orange/yellow than red masonry; hue separates
	# them because both materials can have similar RGB channel ordering.
	if hue > 0.045 and hue < 0.13 and color.r > color.g * 1.10 and color.g > color.b * 1.08 and luminance < 0.68:
		return "wood"
	if color.r > color.g * 1.20 and color.r > color.b * 1.28 and saturation > 0.22:
		return "brick"
	if saturation < 0.12 and luminance < 0.58:
		return "metal"
	if saturation < 0.14:
		return "concrete"
	return "plaster"

static func get_maps(surface: String) -> Dictionary:
	var kind := surface if ["glass", "brick", "wood", "metal", "roof", "concrete", "plaster", "painted_metal"].has(surface) else "plaster"
	if _cache.has(kind):
		return _cache[kind]

	var base := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	var normal := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	var roughness := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	var metallic := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var tone := _pattern_value(kind, x, y)
			var shade := clampf(0.84 + tone * 0.18, 0.62, 1.0)
			base.set_pixel(x, y, Color(shade, shade, shade))
			var nx := clampf(0.5 - _pattern_value(kind, x + 1, y) * 0.035, 0.40, 0.60)
			var ny := clampf(0.5 - _pattern_value(kind, x, y + 1) * 0.035, 0.40, 0.60)
			normal.set_pixel(x, y, Color(nx, ny, 0.98))
			var rough := 0.78
			var metal_value := 0.0
			match kind:
				"glass":
					rough = 0.16 + absf(sin(float(x) * 0.11)) * 0.07
					metal_value = 0.08
				"metal", "painted_metal":
					rough = 0.34 + tone * 0.12
					metal_value = 0.72 if kind == "metal" else 0.34
				"wood":
					rough = 0.68 + tone * 0.12
				"brick":
					rough = 0.88
				"roof":
					rough = 0.76
				"concrete":
					rough = 0.94
				_:
					rough = 0.84
			roughness.set_pixel(x, y, Color(rough, rough, rough))
			metallic.set_pixel(x, y, Color(metal_value, metal_value, metal_value))

	var result := {
		"albedo": ImageTexture.create_from_image(base),
		"normal": ImageTexture.create_from_image(normal),
		"roughness": ImageTexture.create_from_image(roughness),
		"metallic": ImageTexture.create_from_image(metallic),
	}
	_cache[kind] = result
	return result

static func _pattern_value(kind: String, x: int, y: int) -> float:
	var px := posmod(x, TEXTURE_SIZE)
	var py := posmod(y, TEXTURE_SIZE)
	var grain := sin(float(x * 17 + y * 31) * 0.071) * 0.22 + sin(float(x * 7 - y * 13) * 0.19) * 0.12
	match kind:
		"brick":
			var row := py % 20
			var stagger := 12 if int(py / 20) % 2 == 0 else 0
			var joint := row < 2 or posmod(px + stagger, 32) < 2
			return 0.38 if joint else 0.78 + grain * 0.35
		"roof":
			var row := py % 16
			var stagger := 16 if int(py / 16) % 2 == 0 else 0
			var seam := row < 2 or posmod(px + stagger, 32) < 2
			return 0.42 if seam else 0.80 + grain * 0.30
		"wood":
			var stripe := absf(sin(float(x) * 0.17 + sin(float(y) * 0.045) * 1.4))
			var knot := exp(-pow((float(x % 53) - 24.0) / 5.0, 2.0) - pow((float(y % 71) - 36.0) / 9.0, 2.0))
			return clampf(0.52 + stripe * 0.30 + knot * 0.18 + grain * 0.18, 0.0, 1.0)
		"glass":
			var reflection := pow(maxf(0.0, sin(float(x) * 0.045 + 0.8)), 8.0)
			return clampf(0.70 + reflection * 0.25 + grain * 0.05, 0.0, 1.0)
		"metal", "painted_metal":
			var brushed := sin(float(y) * 1.8) * 0.12
			var seam := 0.12 if posmod(y, 64) < 2 else 0.0
			return clampf(0.74 + brushed + grain * 0.12 - seam, 0.0, 1.0)
		"concrete":
			var aggregate := sin(float(x * 13 + y * 19) * 0.31) * sin(float(x * 5 - y * 23) * 0.17)
			return clampf(0.72 + aggregate * 0.17 + grain * 0.20, 0.0, 1.0)
		_:
			var plaster_noise := sin(float(x * 11 + y * 29) * 0.09) * sin(float(x * 23 - y * 3) * 0.07)
			return clampf(0.78 + plaster_noise * 0.12 + grain * 0.18, 0.0, 1.0)
