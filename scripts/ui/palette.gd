class_name BHUI
extends RefCounted
const INK = Color("294950")
const PAPER = Color("f2edde")
const MUTED = Color("6c817e")
const ACCENT = Color("a8774e")
const DARK = Color("182f3b")

static func style(fill: Color, edge: Color = Color("b9beb0"), radius: int = 3) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 11
	box.content_margin_bottom = 11
	return box

static func theme() -> Theme:
	var value = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic","sans-serif"])
	value.default_font = font
	value.default_font_size = 18
	value.set_color("font_color","Label",INK)
	value.set_color("font_color","Button",INK)
	value.set_color("font_hover_color","Button",Color("152e36"))
	value.set_color("font_pressed_color","Button",PAPER)
	value.set_color("font_disabled_color","Button",Color("87948d"))
	value.set_stylebox("normal","Button",style(Color("e9e6d8")))
	value.set_stylebox("hover","Button",style(Color("d7e0d4"),Color("6c918a")))
	value.set_stylebox("pressed","Button",style(Color("456f71")))
	value.set_stylebox("disabled","Button",style(Color("e3e3d8"),Color("ccd0c4")))
	value.set_stylebox("focus","Button",style(Color(0,0,0,0),ACCENT))
	value.set_stylebox("panel","PanelContainer",style(PAPER))
	value.set_constant("separation","VBoxContainer",12)
	value.set_constant("separation","HBoxContainer",12)
	value.set_stylebox("background","ProgressBar",style(Color("40505a"),Color("40505a"),2))
	value.set_stylebox("fill","ProgressBar",style(Color("9bc2b4"),Color("9bc2b4"),2))
	return value

static func label(text: String, size: int = 18, color: Color = INK, wrap: bool = false) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 46
	node.disabled = disabled
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	return node

static func card(parent: Control, heading: String, detail: String = "") -> VBoxContainer:
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel",style(Color("e8e8dc"),Color("c6ccbf")))
	parent.add_child(box)
	var content = VBoxContainer.new()
	box.add_child(content)
	content.add_child(label(heading,21))
	if not detail.is_empty():
		content.add_child(label(detail,17,MUTED,true))
	return content
