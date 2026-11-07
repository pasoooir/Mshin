extends RefCounted
## Local lossless icon atlas. Source sheets stay in res://assets/icons and each
## requested atlas cell is cropped to an uncompressed RGBA ImageTexture at runtime.
## Per-cell edge flood fill removes baked sheet backgrounds without erasing
## enclosed white details or colored artwork.

const SHEET_PATHS := {
	1: "res://assets/icons/Sheet1.png",
	2: "res://assets/icons/Sheet2.png",
	3: "res://assets/icons/Sheet3.png"
}

const SHEETS := {
	1: preload("res://assets/icons/Sheet1.png"),
	2: preload("res://assets/icons/Sheet2.png"),
	3: preload("res://assets/icons/Sheet3.png")
}

static var _texture_cache: Dictionary = {}

const REGIONS := {
	"road": [1, Rect2i(20, 20, 270, 240)],
	"residential": [1, Rect2i(300, 20, 270, 240)],
	"commercial": [1, Rect2i(580, 20, 270, 240)],
	"industrial": [1, Rect2i(860, 20, 270, 240)],
	"power": [1, Rect2i(20, 280, 270, 240)],
	"water": [1, Rect2i(300, 280, 270, 240)],
	"park": [1, Rect2i(580, 280, 270, 240)],
	"specializations": [1, Rect2i(580, 280, 270, 240)],
	"bulldoze": [1, Rect2i(860, 280, 270, 240)],
	"storage": [1, Rect2i(20, 540, 270, 220)],
	"trade": [1, Rect2i(300, 540, 270, 220)],
	"save": [1, Rect2i(580, 540, 270, 220)],
	"cancel": [1, Rect2i(860, 540, 270, 220)],

	"happiness": [2, Rect2i(20, 20, 270, 240)],
	"population": [2, Rect2i(300, 20, 270, 240)],
	"golden_key": [2, Rect2i(580, 20, 270, 240)],
	"simoleons": [2, Rect2i(860, 20, 270, 240)],
	"hard_hat": [2, Rect2i(20, 280, 270, 240)],
	"fire": [2, Rect2i(300, 280, 270, 240)],
	"services": [2, Rect2i(300, 280, 270, 240)],
	"police": [2, Rect2i(580, 280, 270, 240)],
	"health": [2, Rect2i(860, 280, 270, 240)],
	"sewage": [2, Rect2i(20, 540, 270, 220)],
	"waste": [2, Rect2i(300, 540, 270, 220)],
	"government": [2, Rect2i(580, 540, 270, 220)],
	"level": [2, Rect2i(860, 540, 270, 220)],

	"education": [3, Rect2i(20, 20, 270, 180)],
	"transportation": [3, Rect2i(300, 20, 270, 180)],
	"entertainment": [3, Rect2i(580, 20, 270, 180)],
	"gambling": [3, Rect2i(20, 220, 270, 180)],
	"beach": [3, Rect2i(300, 220, 270, 180)],
	"mountain": [3, Rect2i(580, 220, 270, 180)],
	"landmark": [3, Rect2i(20, 420, 270, 180)],
	"parks": [3, Rect2i(300, 420, 270, 180)],
	"trade_depot": [3, Rect2i(580, 420, 270, 180)],
	"global_trade": [3, Rect2i(20, 620, 270, 150)],
	"epic": [3, Rect2i(300, 620, 270, 150)],
	"regions": [3, Rect2i(580, 620, 270, 150)]
}

static func validate_sheets() -> bool:
	var valid := true
	for sheet_id in SHEETS:
		var texture: Texture2D = SHEETS[sheet_id]
		if texture == null:
			push_error("Icon atlas sheet %d failed to import: %s" % [sheet_id, SHEET_PATHS[sheet_id]])
			valid = false
			continue
		var image := texture.get_image()
		if image == null or image.is_empty():
			push_error("Icon atlas sheet %d could not be decoded" % sheet_id)
			valid = false
			continue
		var size := image.get_size()
		if size.x < 1130 or size.y < 770:
			push_error("Icon atlas sheet %d is smaller than expected: %s" % [sheet_id, str(size)])
			valid = false
	for icon_name in REGIONS:
		var entry: Array = REGIONS[icon_name]
		var sheet_id := int(entry[0])
		if not SHEETS.has(sheet_id) or SHEETS[sheet_id] == null:
			push_error("Icon '%s' references unavailable sheet %d" % [icon_name, sheet_id])
			valid = false
			continue
		var rect: Rect2i = entry[1]
		var sheet_size := SHEETS[sheet_id].get_size()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > sheet_size.x or rect.end.y > sheet_size.y:
			push_error("Icon '%s' region %s exceeds sheet %d bounds %s" % [icon_name, str(rect), sheet_id, str(sheet_size)])
			valid = false
	return valid

static func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

static func _make_transparent_cell(sheet_id: int, region: Rect2i) -> Texture2D:
	var cache_key := "%d:%d:%d:%d:%d" % [sheet_id, region.position.x, region.position.y, region.size.x, region.size.y]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var source: Texture2D = SHEETS[sheet_id]
	var source_image := source.get_image()
	if source_image == null or source_image.is_empty():
		push_error("Cannot decode icon sheet %d" % sheet_id)
		return null
	source_image.convert(Image.FORMAT_RGBA8)

	# A tight crop prevents adjacent atlas cells from bleeding into the icon.
	# Two pixels are trimmed from the outer cell gutter, not from the artwork.
	var crop_rect := Rect2i(region.position + Vector2i(2, 2), region.size - Vector2i(4, 4))
	var crop := Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
	crop.blit_rect(source_image, crop_rect, Vector2i.ZERO)

	var width := crop.get_width()
	var height := crop.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	var background_colors: Array[Color] = []

	# Use the four corners as independent background seeds. This supports
	# checkerboard, gray, blue and dark neutral sheet backdrops.
	for point in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		var sample := crop.get_pixel(point.x, point.y)
		if sample.a > 0.01:
			background_colors.append(sample)
	for x in range(width):
		queue.append(x)
		queue.append((height - 1) * width + x)
	for y in range(height):
		queue.append(y * width)
		queue.append(y * width + width - 1)

	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		if index < 0 or index >= visited.size() or visited[index] == 1:
			continue
		visited[index] = 1
		var px := index % width
		var py := int(index / width)
		var color := crop.get_pixel(px, py)
		var matches_background := false
		for background in background_colors:
			if _color_distance(color, background) <= 0.22:
				matches_background = true
				break
		# Also remove the familiar low-saturation light checkerboard.
		var max_channel := maxf(color.r, maxf(color.g, color.b))
		var min_channel := minf(color.r, minf(color.g, color.b))
		if not matches_background and max_channel - min_channel <= 0.08 and min_channel >= 0.58:
			matches_background = true
		if not matches_background:
			continue

		color.a = 0.0
		crop.set_pixel(px, py, color)
		if px > 0: queue.append(index - 1)
		if px + 1 < width: queue.append(index + 1)
		if py > 0: queue.append(index - width)
		if py + 1 < height: queue.append(index + width)

	# Runtime ImageTexture is RGBA and uncompressed; no mipmaps are generated.
	var result := ImageTexture.create_from_image(crop)
	_texture_cache[cache_key] = result
	return result

static func texture_for(icon_name: String) -> Texture2D:
	if not REGIONS.has(icon_name):
		push_error("Unknown UI atlas icon: " + icon_name)
		return null
	var entry: Array = REGIONS[icon_name]
	return _make_transparent_cell(int(entry[0]), entry[1])

static func make_icon(icon_name: String, display_size: Vector2 = Vector2(64, 64)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture_for(icon_name)
	icon.custom_minimum_size = display_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE
	return icon
