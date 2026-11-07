extends RefCounted
## Local sprite-sheet atlas registry. All three PNG sheets are imported from res://;
## missing keys and out-of-bounds regions are reported instead of rendering blank slots.

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

# Each region is kept inside its source sheet. The cells include a small safety
# margin so neighboring artwork cannot bleed into the icon when scaled.
static var _cleaned_sheets: Dictionary = {}

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
		var size := texture.get_size()
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
		var sheet_size: Vector2 = SHEETS[sheet_id].get_size()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > sheet_size.x or rect.end.y > sheet_size.y:
			push_error("Icon '%s' region %s exceeds sheet %d bounds %s" % [icon_name, str(rect), sheet_id, str(sheet_size)])
			valid = false
	return valid

static func _get_clean_sheet(sheet_id: int) -> Texture2D:
	if _cleaned_sheets.has(sheet_id):
		return _cleaned_sheets[sheet_id]
	if not SHEETS.has(sheet_id) or SHEETS[sheet_id] == null:
		return null

	var source: Texture2D = SHEETS[sheet_id]
	var image := source.get_image()
	if image == null or image.is_empty():
		push_error("Could not read icon sheet image %d" % sheet_id)
		return source
	image.convert(Image.FORMAT_RGBA8)

	# The supplied sprite sheets contain a baked light-gray checkerboard.
	# Remove only neutral, bright pixels connected to the sheet's outer edge,
	# preserving colored artwork and enclosed white details.
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()

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
		var py := index / width
		var color := image.get_pixel(px, py)
		var brightest := maxf(color.r, maxf(color.g, color.b))
		var darkest := minf(color.r, minf(color.g, color.b))
		if color.a <= 0.01 or brightest - darkest > 0.13 or darkest < 0.52:
			continue
		color.a = 0.0
		image.set_pixel(px, py, color)
		if px > 0: queue.append(index - 1)
		if px + 1 < width: queue.append(index + 1)
		if py > 0: queue.append(index - width)
		if py + 1 < height: queue.append(index + width)

	var cleaned := ImageTexture.create_from_image(image)
	_cleaned_sheets[sheet_id] = cleaned
	return cleaned

static func texture_for(icon_name: String) -> AtlasTexture:
	if not REGIONS.has(icon_name):
		push_error("Unknown UI atlas icon: " + icon_name)
		return null
	var entry: Array = REGIONS[icon_name]
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _get_clean_sheet(int(entry[0]))
	atlas_texture.region = entry[1]
	atlas_texture.filter_clip = true
	return atlas_texture

static func make_icon(icon_name: String, display_size: Vector2 = Vector2(64, 64)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture_for(icon_name)
	icon.custom_minimum_size = display_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
