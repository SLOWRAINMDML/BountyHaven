extends Control
## Editor/desktop reference viewer only. Does not modify gameplay, saves, or art files.
const MANIFEST_PATH: String = "res://art/reference/manifest.json"
var entries: Array = []
var current: int = 0
var items: ItemList
var picture: TextureRect
var detail: RichTextLabel
var heading: Label
var source_mode: OptionButton
var message: Label

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("111b20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := Label.new()
	title.text = "BOUNTYHAVEN / VISUAL REFERENCE LIBRARY"
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	var warning := Label.new()
	warning.text = "Concept mockups only. UI / characters are baked in. Not playable scenes or extracted layers."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(warning)
	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	items = ItemList.new()
	items.custom_minimum_size.x = 290
	items.item_selected.connect(_select)
	columns.add_child(items)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 20)
	right.add_child(heading)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	right.add_child(picture)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(message)
	detail = RichTextLabel.new()
	detail.custom_minimum_size.y = 105
	detail.bbcode_enabled = false
	right.add_child(detail)
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_add_button(toolbar, "Previous", func() -> void: _select(posmod(current - 1, maxi(1, entries.size()))))
	_add_button(toolbar, "Next", func() -> void: _select(posmod(current + 1, maxi(1, entries.size()))))
	source_mode = OptionButton.new()
	source_mode.add_item("Original PNG")
	source_mode.add_item("Preview JPEG")
	source_mode.item_selected.connect(func(_index: int) -> void: _select(current))
	toolbar.add_child(source_mode)
	_add_button(toolbar, "Copy source path", _copy_path)
	_add_button(toolbar, "Open source folder", _open_folder)
	_add_button(toolbar, "Open browser gallery", _open_browser)
	if not FileAccess.file_exists(MANIFEST_PATH):
		message.text = "Missing manifest: " + MANIFEST_PATH
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		message.text = "Invalid manifest JSON."
		return
	var raw: Variant = parsed.get("assets", [])
	if not raw is Array:
		message.text = "Manifest assets must be an array."
		return
	for entry in raw:
		if entry is Dictionary and entry.has("original") and entry.has("title_en"):
			entries.append(entry)
			items.add_item("%02d  %s" % [int(entry.get("order", entries.size())), str(entry.title_en)])
	if entries.is_empty():
		message.text = "No reference entries."
	else:
		_select(0)

func _add_button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)

func _resource_path() -> String:
	if entries.is_empty():
		return ""
	var key: String = "original" if source_mode.selected == 0 else "preview"
	var relative: String = str(entries[current].get(key, ""))
	if not relative.begins_with("art/reference/") or ".." in relative or "\\" in relative:
		return ""
	return "res://" + relative

func _select(index: int) -> void:
	if entries.is_empty():
		return
	current = clampi(index, 0, entries.size() - 1)
	items.select(current)
	items.ensure_current_is_visible()
	var entry: Dictionary = entries[current]
	heading.text = "%02d / %02d  |  %s  |  Set %d" % [current + 1, entries.size(), entry.title_en, int(entry.get("set", 1))]
	picture.texture = null
	var path: String = _resource_path()
	detail.text = "%s\nOriginal: %s\nSHA-256: %s\nLayers: NOT EXTRACTED | Production ready: NO" % [str(entry.id), str(entry.original), str(entry.sha256)]
	if path.is_empty() or not FileAccess.file_exists(path):
		message.text = "Image not installed. Add the original art pack; the manifest alone is not the artwork."
		return
	var image := Image.new()
	var err: Error = image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		message.text = "Image decode failed (%d): %s" % [err, path]
		return
	picture.texture = ImageTexture.create_from_image(image)
	message.text = "%d x %d | Aspect ratio preserved | %s" % [image.get_width(), image.get_height(), path.get_file()]

func _copy_path() -> void:
	if not entries.is_empty():
		DisplayServer.clipboard_set(_resource_path())

func _open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("res://art/reference/originals"))

func _open_browser() -> void:
	OS.shell_open(ProjectSettings.globalize_path("res://art/reference/index.html"))
