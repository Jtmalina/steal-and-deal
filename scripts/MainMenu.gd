extends CanvasLayer
class_name MainMenu
# ============================================================
#  The screen before the game. New, load, or leave.
#
#  It sits on top of nothing: the world is not built until you
#  pick something, so a cold start is a menu and a colour, and
#  the shop only gets assembled once you have said which one.
# ============================================================

signal chose(what: String)

const GOLD := Color(1.0, 0.8, 0.2)

func _ready() -> void:
	layer = 50
	var back := ColorRect.new()
	back.color = Color(0.06, 0.06, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.offset_left = -230
	box.offset_right = 230
	box.offset_top = -180
	box.offset_bottom = 200
	add_child(box)

	box.add_child(_label("STEAL AND DEAL", 54, GOLD))
	box.add_child(_label("Friend Slop Chop Shop", 20, Color(0.7, 0.7, 0.7)))
	box.add_child(_gap(24))

	box.add_child(_button("NEW GAME", func(): chose.emit("new")))
	var save_stamp := SaveGame.stamp()
	var load_btn := _button("LOAD GAME", func(): chose.emit("load"))
	load_btn.disabled = save_stamp == ""
	box.add_child(load_btn)
	box.add_child(_label("last saved %s" % save_stamp if save_stamp != "" else "no save on this machine",
		15, Color(0.6, 0.6, 0.6)))
	box.add_child(_gap(18))
	box.add_child(_button("EXIT", func(): chose.emit("exit")))

	box.add_child(_gap(26))
	box.add_child(_label("Steal cars. Take them apart. Sell the pieces. Do not get caught.",
		16, Color(0.55, 0.55, 0.55)))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
