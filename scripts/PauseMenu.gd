extends CanvasLayer
class_name PauseMenu
# ============================================================
#  Stop the world. Carry on, write it down, go back to the front
#  screen, or leave altogether.
#
#  The tree is paused underneath this, so nothing moves while it
#  is up -- but the menu itself has to keep running, hence the
#  ALWAYS process mode on it.
# ============================================================

signal chose(what: String)

const GOLD := Color(1.0, 0.8, 0.2)

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

	var back := ColorRect.new()
	back.color = Color(0.04, 0.05, 0.07, 0.82)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -170
	box.offset_bottom = 180
	add_child(box)

	box.add_child(_label("PAUSED", 44, GOLD))
	box.add_child(_gap(18))
	box.add_child(_button("RESUME", func(): chose.emit("resume")))
	box.add_child(_button("SAVE THE GAME", func(): chose.emit("save")))
	box.add_child(_gap(14))
	box.add_child(_button("QUIT TO MENU", func(): chose.emit("menu")))
	box.add_child(_button("QUIT TO DESKTOP", func(): chose.emit("desktop")))
	box.add_child(_gap(16))
	box.add_child(_label("[Esc] to carry on   -   [F11] windowed", 14, Color(0.6, 0.6, 0.6)))

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	return b

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
