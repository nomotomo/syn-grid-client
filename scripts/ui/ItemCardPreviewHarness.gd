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

func _on_card_pressed(item_data: Dictionary) -> void:
	_status_label.text = "card_pressed -> %s" % item_data.get("name", "?")

func _on_drag_started(card: ItemCard) -> void:
	_status_label.text = "drag_started -> %s" % _card_name(card)

func _on_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	_status_label.text = "drag_ended -> %s at %s" % [_card_name(card), drop_pos]

func _card_name(card: ItemCard) -> String:
	var data: Dictionary = card.get("_item_data")
	return data.get("name", "?")
