extends Node

# Standalone headless check for PostMortemRules (issue #31 acceptance).
# Run: godot --headless --path . tests/PostMortemRulesVerify.tscn
# Exit 0 on pass, 1 on any assertion failure.

func _ready() -> void:
	var failures: Array[String] = []
	failures.append_array(_check_never_fired())
	failures.append_array(_check_destroyed_early())
	failures.append_array(_check_never_synergized())
	failures.append_array(_check_empty())
	if failures.is_empty():
		print("PostMortemRulesVerify: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("PostMortemRulesVerify: FAIL (%d)" % failures.size())
		get_tree().quit(1)

func _check_never_fired() -> Array[String]:
	var out: Array[String] = []
	var lines := PostMortemRules.generate(
		[{"item_id": "a", "shots_fired": 0, "damage_dealt": 0.0},
			{"item_id": "b", "shots_fired": 5, "damage_dealt": 10.0}],
		[],
		["a", "b"],
		{"a": "Dusty Relic", "b": "Sword"})
	if lines.is_empty() or not String(lines[0]).contains("never fired"):
		out.append("rule1 expected never-fired line, got %s" % str(lines))
	elif not String(lines[0]).contains("Dusty Relic"):
		out.append("rule1 expected name Dusty Relic, got %s" % str(lines[0]))
	return out

func _check_destroyed_early() -> Array[String]:
	var out: Array[String] = []
	var lines := PostMortemRules.generate(
		[{"item_id": "a", "shots_fired": 3}, {"item_id": "b", "shots_fired": 3}],
		[{"tick": 22, "killing_blow": true, "target_item_id": "a",
			"firing_item_id": "opp", "synergy_bonus": 1.0}],
		["a", "b"],
		{"a": "Shortsword", "b": "Bow"})
	var found := false
	for line in lines:
		if String(line).contains("You lost Shortsword at tick 22"):
			found = true
	if not found:
		out.append("rule2 expected destroyed-early line, got %s" % str(lines))
	return out

func _check_never_synergized() -> Array[String]:
	var out: Array[String] = []
	var lines := PostMortemRules.generate(
		[{"item_id": "loner", "shots_fired": 4}, {"item_id": "buddy", "shots_fired": 4}],
		[{"tick": 1, "firing_item_id": "buddy", "synergy_bonus": 5.0, "killing_blow": false},
			{"tick": 2, "firing_item_id": "loner", "synergy_bonus": 0.0, "killing_blow": false}],
		["loner", "buddy"],
		{"loner": "Lonely Staff", "buddy": "Buddy Blade"})
	var found := false
	for line in lines:
		if String(line).contains("never synergized") and String(line).contains("Lonely Staff"):
			found = true
	if not found:
		out.append("rule3 expected never-synergized line, got %s" % str(lines))
	return out

func _check_empty() -> Array[String]:
	var out: Array[String] = []
	var lines := PostMortemRules.generate(
		[{"item_id": "a", "shots_fired": 2}, {"item_id": "b", "shots_fired": 2}],
		[{"tick": 1, "firing_item_id": "a", "synergy_bonus": 3.0, "killing_blow": false},
			{"tick": 2, "firing_item_id": "b", "synergy_bonus": 1.0, "killing_blow": false}],
		["a", "b"],
		{"a": "A", "b": "B"})
	if not lines.is_empty():
		out.append("empty case expected [], got %s" % str(lines))
	return out
