extends Control

# Dev-only visual harness for manually checking the theme + ItemCard feel
# before any real screen is built on top of them. Not one of the six
# production screens - open this scene directly in the editor and press F6
# to run it standalone (the project has no main scene yet, so F5 won't work).

const SAMPLE_ITEMS: Array[Dictionary] = [
	{"name": "Shortsword", "weapon_category": "MELEE", "buy_price": 3},
	{"name": "Longbow", "weapon_category": "RANGED", "buy_price": 4},
	{"name": "Arcane Staff", "weapon_category": "ARCANE", "buy_price": 5},
	{"name": "Iron Buckler", "weapon_category": "", "level": 3},
	{"name": "Ember Wand", "weapon_category": "ARCANE", "buy_price": 9},
	{"name": "Iron Sword", "weapon_category": "MELEE", "buy_price": 6},
	{"name": "Healing Draught", "weapon_category": "", "buy_price": 2},
	{"name": "Leather Armor", "weapon_category": "", "buy_price": 4},
	# Permanent fallback regression: no matching sprite file for this name.
	{"name": "Mystery Blade", "weapon_category": "MELEE", "buy_price": 99},
]

@onready var _background: ColorRect = %Background
@onready var _card_row: HBoxContainer = %CardRow
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG

	var card_scene: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
	for i in SAMPLE_ITEMS.size():
		var card: ItemCard = card_scene.instantiate()
		_card_row.add_child(card)
		card.set_item_data(SAMPLE_ITEMS[i])
		card.play_pop(i)
		card.card_pressed.connect(_on_card_pressed)
		card.drag_started.connect(_on_drag_started)
		card.drag_ended.connect(_on_drag_ended)

	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path != "":
		_run_screenshot_verify(screenshot_path)

func _run_screenshot_verify(screenshot_path: String) -> void:
	for _i in 60:
		await get_tree().process_frame
	_save_and_quit(screenshot_path)

func _save_and_quit(screenshot_path: String) -> void:
	var tex := get_viewport().get_texture()
	if tex:
		var image := tex.get_image()
		if image:
			image.save_png(screenshot_path)
			print("auto-verify: screenshot saved to ", screenshot_path)
		else:
			print("auto-verify: no image buffer (headless) - skipping screenshot")
	else:
		print("auto-verify: no viewport texture (headless) - skipping screenshot")
	get_tree().quit()

func _on_card_pressed(item_data: Dictionary) -> void:
	_status_label.text = "card_pressed -> %s" % item_data.get("name", "?")

func _on_drag_started(card: ItemCard) -> void:
	_status_label.text = "drag_started -> %s" % _card_name(card)

func _on_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	_status_label.text = "drag_ended -> %s at %s" % [_card_name(card), drop_pos]

func _card_name(card: ItemCard) -> String:
	var data: Dictionary = card.get("_item_data")
	return data.get("name", "?")
