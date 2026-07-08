class_name BattleReportScene
extends Control

# E4 / issue #31: post-fight battle report between CombatReplay and RoundEnd.
# Every number is a direct read or single-pass sum of server fields - no client
# combat math. Pages share one _analyze_events() pass at scene entry.

const ROUND_END_SCENE_PATH: String = "res://scenes/round_end/RoundEndScene.tscn"
const ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
const COMBAT_MAX_HP: float = 1000.0
const PAGE_COUNT: int = 5

@export var banner_pop_duration: float = 0.12
@export var banner_settle_duration: float = 0.06
@export var page_tween_duration: float = 0.18
@export var mini_cell_card_size: Vector2 = Vector2(72, 72)
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var ranked_bar_max_width: float = 220.0

@onready var _background: ColorRect = %Background
@onready var _page_title: Label = %PageTitle
@onready var _page_host: Control = %PageHost
@onready var _skip_button: Button = %SkipButton
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton

var _log: Dictionary = {}
var _own_items_by_id: Dictionary = {}
var _opp_items_by_id: Dictionary = {}
var _damage_by_item_id: Dictionary = {}
var _taken_by_item_id: Dictionary = {}
var _crit_rate_by_item_id: Dictionary = {}
var _shots_by_item_id: Dictionary = {}
var _synergy_by_category: Dictionary = {}
var _damage_by_cell: Dictionary = {}
var _taken_by_cell: Dictionary = {}
var _hp_series_by_side: Dictionary = {}  # "player"/"opponent" -> Array[{tick, hp}]
var _current_page: int = 0
var _pages: Array[Control] = []
var _heatmap_built: bool = false
var _scrubber_built: bool = false
var _player_scrub_bar: HpBar = null
var _opp_scrub_bar: HpBar = null
var _scrub_slider: HSlider = null
var _attacker_is_player: bool = true
var _opponent_player_id: String = ""

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_log = GameState.last_combat_log
	_build_item_maps()
	_seed_item_stats()
	_analyze_events()
	# Wait one frame so Control size matches the viewport (540x960 harness)
	# before absolute layout - otherwise chrome/page builds see stale dims.
	await get_tree().process_frame
	_layout_chrome()
	_pages.clear()
	for i in PAGE_COUNT:
		var page := Control.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		_page_host.add_child(page)
		_pages.append(page)
	_build_verdict_page(_pages[0])
	_skip_button.pressed.connect(_go_to_round_end)
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_show_page(0, false)

func _vp() -> Vector2:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		return rect.size
	return size if size.x > 1.0 else Vector2(540.0, 960.0)

func _build_item_maps() -> void:
	_own_items_by_id.clear()
	for item: Dictionary in GameState.equipped_items:
		_own_items_by_id[String(item.get("item_id", ""))] = item
	_opp_items_by_id.clear()
	for item: Dictionary in GameState.opponent_grid.get("equipped_items", []):
		_opp_items_by_id[String(item.get("item_id", ""))] = item
	var attacker_id := String(_log.get("attacker_id", GameState.player_id))
	var defender_id := String(_log.get("defender_id", ""))
	_attacker_is_player = attacker_id == GameState.player_id
	_opponent_player_id = defender_id if _attacker_is_player else attacker_id

func _seed_item_stats() -> void:
	_damage_by_item_id.clear()
	_taken_by_item_id.clear()
	_crit_rate_by_item_id.clear()
	_shots_by_item_id.clear()
	var summary: Dictionary = _log.get("summary", {})
	for s: Dictionary in summary.get("item_stats", []):
		var id := String(s.get("item_id", ""))
		_damage_by_item_id[id] = float(s.get("damage_dealt", 0.0))
		_taken_by_item_id[id] = float(s.get("damage_taken", 0.0))
		var shots := int(s.get("shots_fired", 0))
		_shots_by_item_id[id] = shots
		var crits := int(s.get("crits", 0))
		_crit_rate_by_item_id[id] = (float(crits) / float(shots)) if shots > 0 else 0.0

func _analyze_events() -> void:
	_synergy_by_category.clear()
	_damage_by_cell.clear()
	_taken_by_cell.clear()
	_hp_series_by_side = {
		"player": [{"tick": 0, "hp": COMBAT_MAX_HP}],
		"opponent": [{"tick": 0, "hp": COMBAT_MAX_HP}],
	}
	for ev: Dictionary in _log.get("events", []):
		var firing_id := String(ev.get("firing_item_id", ""))
		var bonus := float(ev.get("synergy_bonus", 0.0))
		if bonus > 0.0:
			var item: Dictionary = _own_items_by_id.get(firing_id,
				_opp_items_by_id.get(firing_id, {}))
			var category := String(item.get("weapon_category", ""))
			if category == "":
				category = "OTHER"
			_synergy_by_category[category] = float(
				_synergy_by_category.get(category, 0.0)) + bonus

		var source = ev.get("source_cell")
		if source is Dictionary:
			var sx := int(source.get("x", 0))
			var sy := int(source.get("y", 0))
			# Own-side coords are as-placed; opponent cells are
			# mirrored the same way CombatReplayScene._build_side
			# mirrors the opponent board.
			var mirror_src := not _own_items_by_id.has(firing_id)
			if mirror_src:
				sx = grid_columns - 1 - sx
			var skey := Vector2i(sx, sy)
			# Tag keys with side so opponent/player heatmaps don't collide.
			var side_s := "opp" if mirror_src else "own"
			var full_skey := "%s:%d,%d" % [side_s, skey.x, skey.y]
			_damage_by_cell[full_skey] = float(
				_damage_by_cell.get(full_skey, 0.0)) + float(ev.get("actual_damage", 0.0))

		var target = ev.get("target_cell")
		if target is Dictionary:
			var tx := int(target.get("x", 0))
			var ty := int(target.get("y", 0))
			var target_pid := String(ev.get("target_player_id", ""))
			var mirror_tgt := target_pid != GameState.player_id
			if mirror_tgt:
				tx = grid_columns - 1 - tx
			var side_t := "opp" if mirror_tgt else "own"
			var full_tkey := "%s:%d,%d" % [side_t, tx, ty]
			_taken_by_cell[full_tkey] = float(
				_taken_by_cell.get(full_tkey, 0.0)) + float(ev.get("hp_loss", 0.0))

		var tick := int(ev.get("tick", 0))
		var target_pid2 := String(ev.get("target_player_id", ""))
		var side_key := "player" if target_pid2 == GameState.player_id else "opponent"
		var series: Array = _hp_series_by_side[side_key]
		series.append({"tick": tick, "hp": float(ev.get("target_hp_after", 0.0))})

func _layout_chrome() -> void:
	var w := _vp().x
	var h := _vp().y
	_page_title.position = Vector2(40.0, 28.0)
	_page_title.size = Vector2(w - 200.0, 40.0)
	_skip_button.position = Vector2(w - 160.0, 24.0)
	_skip_button.size = Vector2(120.0, 48.0)
	_page_host.position = Vector2(0.0, 80.0)
	_page_host.size = Vector2(w, h - 200.0)
	_prev_button.position = Vector2(40.0, h - 100.0)
	_prev_button.size = Vector2(160.0, 72.0)
	_next_button.position = Vector2(w - 200.0, h - 100.0)
	_next_button.size = Vector2(160.0, 72.0)

func _page_titles() -> Array[String]:
	return ["VERDICT", "BREAKDOWN", "ADVICE", "HEATMAP", "TIMELINE"]

func _show_page(index: int, animate: bool) -> void:
	_current_page = clampi(index, 0, PAGE_COUNT - 1)
	_ensure_page_built(_current_page)
	_page_title.text = _page_titles()[_current_page]
	for i in _pages.size():
		_pages[i].visible = (i == _current_page)
	_prev_button.disabled = _current_page == 0
	_next_button.text = "CONTINUE" if _current_page == PAGE_COUNT - 1 else "NEXT"
	if animate:
		var page := _pages[_current_page]
		page.modulate.a = 0.0
		page.pivot_offset = page.size / 2.0
		page.scale = Vector2(0.96, 0.96)
		var tw := create_tween()
		tw.tween_property(page, "modulate:a", 1.0, page_tween_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(page, "scale", Vector2.ONE, page_tween_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _ensure_page_built(index: int) -> void:
	match index:
		1:
			if _pages[1].get_child_count() == 0:
				_build_breakdown_page(_pages[1])
		2:
			if _pages[2].get_child_count() == 0:
				_build_advice_page(_pages[2])
		3:
			if not _heatmap_built:
				_build_heatmap_page(_pages[3])
				_heatmap_built = true
		4:
			if not _scrubber_built:
				_build_scrubber_page(_pages[4])
				_scrubber_built = true

func _on_prev_pressed() -> void:
	if _current_page > 0:
		_show_page(_current_page - 1, true)

func _on_next_pressed() -> void:
	if _current_page >= PAGE_COUNT - 1:
		_go_to_round_end()
		return
	_show_page(_current_page + 1, true)

func _go_to_round_end() -> void:
	get_tree().change_scene_to_file(ROUND_END_SCENE_PATH)

# -- Page 1: VERDICT ----------------------------------------------------------

func _build_verdict_page(page: Control) -> void:
	var w := _vp().x
	var won := String(_log.get("winner_id", "")) == GameState.player_id
	var banner := Label.new()
	banner.theme_type_variation = &"TitleLabel"
	banner.add_theme_font_size_override("font_size", 48)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.position = Vector2(40.0, 40.0)
	banner.size = Vector2(w - 80.0, 100.0)
	if won:
		banner.text = "VICTORY"
		banner.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	else:
		banner.text = "DEFEAT"
		banner.add_theme_color_override("font_color", SynGridPalette.DANGER)
	page.add_child(banner)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2(1.1, 1.1), banner_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(banner, "scale", Vector2.ONE, banner_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

	var one_liner := Label.new()
	one_liner.add_theme_font_size_override("font_size", 18)
	one_liner.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
	one_liner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	one_liner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	one_liner.position = Vector2(40.0, 160.0)
	one_liner.size = Vector2(w - 80.0, 100.0)
	one_liner.text = _verdict_one_liner(won)
	page.add_child(one_liner)

	var meta := Label.new()
	meta.theme_type_variation = &"CaptionLabel"
	meta.add_theme_font_size_override("font_size", 16)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.position = Vector2(40.0, 280.0)
	meta.size = Vector2(w - 80.0, 80.0)
	var total_ticks := int(_log.get("total_ticks", 0))
	var total_dmg := 0.0
	for dmg in _damage_by_item_id.values():
		total_dmg += float(dmg)
	meta.text = "%d ticks\n%d total damage exchanged" % [total_ticks, int(round(total_dmg))]
	meta.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
	page.add_child(meta)

func _verdict_one_liner(won: bool) -> String:
	if won:
		var best_id := ""
		var best_dmg := -1.0
		for id in _own_items_by_id.keys():
			var dmg := float(_damage_by_item_id.get(id, 0.0))
			if dmg > best_dmg:
				best_dmg = dmg
				best_id = String(id)
		var name := String(_own_items_by_id.get(best_id, {}).get("name", best_id))
		return "%s carried the round with %d dmg dealt." % [name, int(round(best_dmg))]
	var best_id2 := ""
	var best_dmg2 := -1.0
	for id in _damage_by_item_id.keys():
		if _own_items_by_id.has(id):
			continue
		var dmg2 := float(_damage_by_item_id.get(id, 0.0))
		if dmg2 > best_dmg2:
			best_dmg2 = dmg2
			best_id2 = String(id)
	var opp_name := String(_opp_items_by_id.get(best_id2, {}).get("name", best_id2))
	if best_id2 == "":
		return "You had no answer."
	return "%s dealt %d dmg - you had no answer." % [opp_name, int(round(best_dmg2))]

# -- Page 2: BREAKDOWN --------------------------------------------------------

func _build_breakdown_page(page: Control) -> void:
	var w := _vp().x
	var host_h := _page_host.size.y if _page_host.size.y > 1.0 else (_vp().y - 200.0)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24.0, 8.0)
	scroll.size = Vector2(w - 48.0, host_h - 16.0)
	page.add_child(scroll)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_add_item_ranked(root, "DAMAGE DEALT", _damage_by_item_id, false)
	_add_item_ranked(root, "DAMAGE TAKEN", _taken_by_item_id, false)
	_add_category_ranked(root, "SYNERGY BY CATEGORY", _synergy_by_category)
	_add_item_ranked(root, "CRIT RATE", _crit_rate_by_item_id, true)

func _add_item_ranked(parent: VBoxContainer, title: String, source: Dictionary,
		as_percent: bool) -> void:
	var ids: Array = []
	for id in _own_items_by_id.keys():
		ids.append(String(id))
	ids.sort_custom(func(a, b):
		return float(source.get(a, 0.0)) > float(source.get(b, 0.0)))
	var rows: Array = []
	for id in ids:
		var v := float(source.get(id, 0.0))
		var value_text := ("%d%%" % int(round(v * 100.0))) if as_percent \
			else str(int(round(v)))
		rows.append({
			"name": String(_own_items_by_id.get(id, {}).get("name", id)),
			"value": v,
			"value_text": value_text,
		})
	_add_ranked_rows(parent, title, rows)

func _add_category_ranked(parent: VBoxContainer, title: String, source: Dictionary) -> void:
	var cats: Array = source.keys()
	cats.sort_custom(func(a, b):
		return float(source[a]) > float(source[b]))
	var rows: Array = []
	for cat in cats:
		var v := float(source.get(cat, 0.0))
		rows.append({
			"name": String(cat),
			"value": v,
			"value_text": str(int(round(v))),
		})
	_add_ranked_rows(parent, title, rows)

func _add_ranked_rows(parent: VBoxContainer, title: String, rows: Array) -> void:
	var caption := Label.new()
	caption.text = title
	caption.theme_type_variation = &"CaptionLabel"
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	parent.add_child(caption)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "(none)"
		empty.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
		parent.add_child(empty)
		return
	var max_v := 0.0
	for row in rows:
		max_v = maxf(max_v, float(row.get("value", 0.0)))
	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var name_l := Label.new()
		name_l.text = String(row.get("name", ""))
		name_l.custom_minimum_size = Vector2(140.0, 0.0)
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
		hbox.add_child(name_l)
		var bar := ColorRect.new()
		var frac := 0.0 if max_v <= 0.0 else float(row.get("value", 0.0)) / max_v
		bar.custom_minimum_size = Vector2(ranked_bar_max_width * frac, 16.0)
		bar.color = Color(SynGridPalette.ACCENT_TEAL, 0.55)
		hbox.add_child(bar)
		var val_l := Label.new()
		val_l.text = String(row.get("value_text", ""))
		val_l.add_theme_font_size_override("font_size", 14)
		val_l.add_theme_color_override("font_color", SynGridPalette.GOLD)
		hbox.add_child(val_l)
		parent.add_child(hbox)

# -- Page 3: ADVICE -----------------------------------------------------------

func _build_advice_page(page: Control) -> void:
	var w := _vp().x
	var host_h := _page_host.size.y if _page_host.size.y > 1.0 else (_vp().y - 200.0)
	var own_ids: Array = _own_items_by_id.keys()
	var id_to_name: Dictionary = {}
	for id in own_ids:
		id_to_name[id] = String(_own_items_by_id[id].get("name", id))
	var summary: Dictionary = _log.get("summary", {})
	var lines: Array[String] = PostMortemRules.generate(
		summary.get("item_stats", []),
		_log.get("events", []),
		own_ids,
		id_to_name)
	var root := VBoxContainer.new()
	root.position = Vector2(40.0, 24.0)
	root.size = Vector2(w - 80.0, host_h - 48.0)
	root.add_theme_constant_override("separation", 16)
	page.add_child(root)
	if lines.is_empty():
		return
	for line_text in lines:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel",
			ThemeBuilder.build_panel_style(SynGridPalette.ACCENT_AMBER,
				SynGridPalette.PANEL_BG_ELEVATED))
		var label := Label.new()
		label.text = line_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
		label.custom_minimum_size = Vector2(w - 120.0, 0.0)
		row.add_child(label)
		root.add_child(row)

# -- Heatmap ------------------------------------------------------------------

func _build_heatmap_page(page: Control) -> void:
	var w := _vp().x
	var caption := Label.new()
	caption.text = "Green = dmg dealt  Blue = dmg taken  Red = never fired"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(20.0, 4.0)
	caption.size = Vector2(w - 40.0, 28.0)
	page.add_child(caption)

	var opp_label := Label.new()
	opp_label.text = "OPPONENT"
	opp_label.add_theme_font_size_override("font_size", 12)
	opp_label.add_theme_color_override("font_color", SynGridPalette.DANGER)
	opp_label.position = Vector2(40.0, 36.0)
	page.add_child(opp_label)
	var opp_grid := GridContainer.new()
	opp_grid.columns = grid_columns
	opp_grid.add_theme_constant_override("h_separation", 0)
	opp_grid.add_theme_constant_override("v_separation", 0)
	var cell_sz := _cell_outer_size()
	var grid_total := cell_sz * Vector2(grid_columns, grid_rows)
	var center_x := (w - grid_total.x) / 2.0
	opp_grid.position = Vector2(center_x, 56.0)
	opp_grid.size = grid_total
	page.add_child(opp_grid)
	_fill_heat_grid(opp_grid, GameState.opponent_grid.get("equipped_items", []), true, "opp")

	var you_label := Label.new()
	you_label.text = "YOU"
	you_label.add_theme_font_size_override("font_size", 12)
	you_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	you_label.position = Vector2(40.0, 56.0 + grid_total.y + 20.0)
	page.add_child(you_label)
	var player_grid := GridContainer.new()
	player_grid.columns = grid_columns
	player_grid.add_theme_constant_override("h_separation", 0)
	player_grid.add_theme_constant_override("v_separation", 0)
	player_grid.position = Vector2(center_x, 56.0 + grid_total.y + 40.0)
	player_grid.size = grid_total
	page.add_child(player_grid)
	_fill_heat_grid(player_grid, GameState.equipped_items, false, "own")

func _cell_outer_size() -> Vector2:
	return mini_cell_card_size + Vector2.ONE * (ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0)

func _fill_heat_grid(container: GridContainer, items: Array, mirror_x: bool, side: String) -> void:
	var cells: Dictionary = {}
	var cell_sz := _cell_outer_size()
	for y in grid_rows:
		for x in grid_columns:
			var cell := GridCell.new()
			cell.setup(x, y, cell_sz)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(cell)
			cells[Vector2i(x, y)] = cell

	var max_dealt := 0.0
	var max_taken := 0.0
	for key in _damage_by_cell.keys():
		if String(key).begins_with(side + ":"):
			max_dealt = maxf(max_dealt, float(_damage_by_cell[key]))
	for key in _taken_by_cell.keys():
		if String(key).begins_with(side + ":"):
			max_taken = maxf(max_taken, float(_taken_by_cell[key]))

	for item: Dictionary in items:
		var coords = item.get("placement_coords")
		if coords == null:
			continue
		var x := int(coords.get("x", 0))
		if mirror_x:
			x = grid_columns - 1 - x
		var y := int(coords.get("y", 0))
		var cell: GridCell = cells.get(Vector2i(x, y))
		if cell == null:
			continue
		var item_id := String(item.get("item_id", ""))
		var heat_key := "%s:%d,%d" % [side, x, y]
		var shots := int(_shots_by_item_id.get(item_id, -1))
		var tint: Color
		if shots == 0 or shots < 0:
			# Never fired (zero shots or absent from item_stats).
			tint = Color(SynGridPalette.DANGER, 0.35)
		else:
			var dealt_a := 0.0 if max_dealt <= 0.0 \
				else float(_damage_by_cell.get(heat_key, 0.0)) / max_dealt
			var taken_a := 0.0 if max_taken <= 0.0 \
				else float(_taken_by_cell.get(heat_key, 0.0)) / max_taken
			var green := Color(SynGridPalette.HP_HIGH.r, SynGridPalette.HP_HIGH.g,
				SynGridPalette.HP_HIGH.b, dealt_a * 0.55)
			var blue := Color(SynGridPalette.HEAT_TAKEN.r, SynGridPalette.HEAT_TAKEN.g,
				SynGridPalette.HEAT_TAKEN.b, taken_a * 0.55)
			tint = Color(
				clampf(green.r * green.a + blue.r * blue.a, 0.0, 1.0),
				clampf(green.g * green.a + blue.g * blue.a, 0.0, 1.0),
				clampf(green.b * green.a + blue.b * blue.a, 0.0, 1.0),
				clampf(green.a + blue.a, 0.08, 0.7))
		cell.set_heat_tint(tint)
		var card: ItemCard = ITEM_CARD_SCENE.instantiate()
		card.card_size = mini_cell_card_size
		card.draggable = false
		cell.add_child(card)
		card.set_item_data(item)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_scrubber_page(page: Control) -> void:
	var w := _vp().x
	var total_ticks := maxi(1, int(_log.get("total_ticks", 1)))
	var summary: Dictionary = _log.get("summary", {})
	var turning := int(summary.get("turning_point_tick", 0))

	_opp_scrub_bar = HpBar.new()
	_opp_scrub_bar.position = Vector2(40.0, 40.0)
	_opp_scrub_bar.size = Vector2(w - 80.0, 52.0)
	page.add_child(_opp_scrub_bar)
	_opp_scrub_bar.setup(COMBAT_MAX_HP, 0.0)

	var opp_cap := Label.new()
	opp_cap.text = "OPPONENT HP"
	opp_cap.add_theme_font_size_override("font_size", 12)
	opp_cap.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
	opp_cap.position = Vector2(40.0, 16.0)
	page.add_child(opp_cap)

	_player_scrub_bar = HpBar.new()
	_player_scrub_bar.position = Vector2(40.0, 140.0)
	_player_scrub_bar.size = Vector2(w - 80.0, 52.0)
	page.add_child(_player_scrub_bar)
	_player_scrub_bar.setup(COMBAT_MAX_HP, 0.0)

	var you_cap := Label.new()
	you_cap.text = "YOUR HP"
	you_cap.add_theme_font_size_override("font_size", 12)
	you_cap.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
	you_cap.position = Vector2(40.0, 116.0)
	page.add_child(you_cap)

	_scrub_slider = HSlider.new()
	_scrub_slider.min_value = 0
	_scrub_slider.max_value = total_ticks
	_scrub_slider.step = 1
	_scrub_slider.value = total_ticks
	_scrub_slider.position = Vector2(40.0, 260.0)
	_scrub_slider.size = Vector2(w - 80.0, 40.0)
	page.add_child(_scrub_slider)
	_scrub_slider.value_changed.connect(_on_scrub_changed)

	var tip := Label.new()
	tip.text = "TURNING POINT"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", SynGridPalette.GOLD)
	var frac := clampf(float(turning) / float(total_ticks), 0.0, 1.0)
	var track_x := 40.0
	var track_w := w - 80.0
	var mark_x := track_x + track_w * frac
	var marker := ColorRect.new()
	marker.color = SynGridPalette.GOLD
	marker.position = Vector2(mark_x - 1.5, 250.0)
	marker.size = Vector2(3.0, 52.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(marker)
	tip.position = Vector2(mark_x - 60.0, 308.0)
	tip.size = Vector2(120.0, 24.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(tip)

	var tick_note := Label.new()
	tick_note.name = "ScrubTickLabel"
	tick_note.add_theme_font_size_override("font_size", 16)
	tick_note.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
	tick_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick_note.position = Vector2(40.0, 340.0)
	tick_note.size = Vector2(w - 80.0, 32.0)
	page.add_child(tick_note)

	_on_scrub_changed(float(total_ticks))

func _on_scrub_changed(value: float) -> void:
	var tick := int(value)
	if _player_scrub_bar != null:
		_player_scrub_bar.set_state(_hp_at("player", tick), 0.0)
	if _opp_scrub_bar != null:
		_opp_scrub_bar.set_state(_hp_at("opponent", tick), 0.0)
	var label := _pages[4].get_node_or_null("ScrubTickLabel") as Label
	if label != null:
		label.text = "TICK %d / %d" % [tick, int(_log.get("total_ticks", 0))]

func _hp_at(side: String, tick: int) -> float:
	var series: Array = _hp_series_by_side.get(side, [])
	var hp := COMBAT_MAX_HP
	for entry in series:
		if int(entry.get("tick", 0)) <= tick:
			hp = float(entry.get("hp", hp))
		else:
			break
	return hp
