class_name PostMortemRules
extends RefCounted

# Pure log-fact rule engine, no gameplay computation. Shared with the future
# adaptive-coaching feature (improvements.md §5.4) - every rule here must be a
# straight read of item_stats/events, never a speculative "what if" claim.
# No GameState or autoload coupling - callers pass id_to_name for display.

static func generate(item_stats: Array, events: Array, own_item_ids: Array,
		id_to_name: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var stats_by_id: Dictionary = {}
	for s: Dictionary in item_stats:
		stats_by_id[String(s.get("item_id", ""))] = s

	# Rule 1: never fired.
	for id in own_item_ids:
		var sid := String(id)
		var s: Dictionary = stats_by_id.get(sid, {})
		if int(s.get("shots_fired", 0)) == 0:
			lines.append("%s never fired this fight - check its placement." % \
				_name_for(sid, id_to_name))
			break  # one example is enough, don't spam every dead card

	# Rule 2: destroyed early (killing_blow landed against one of your own items).
	var own_set: Dictionary = {}
	for id in own_item_ids:
		own_set[String(id)] = true
	for ev: Dictionary in events:
		if not bool(ev.get("killing_blow", false)):
			continue
		var target_id := String(ev.get("target_item_id", ""))
		if own_set.has(target_id):
			lines.append("You lost %s at tick %d." % [
				_name_for(target_id, id_to_name), int(ev.get("tick", 0))])
			break

	# Rule 3: never synergized.
	var synergized_ids: Dictionary = {}
	for ev: Dictionary in events:
		if float(ev.get("synergy_bonus", 0.0)) > 0.0:
			synergized_ids[String(ev.get("firing_item_id", ""))] = true
	for id in own_item_ids:
		var sid := String(id)
		var s: Dictionary = stats_by_id.get(sid, {})
		if int(s.get("shots_fired", 0)) > 0 and not synergized_ids.has(sid):
			lines.append("%s never synergized with a neighbor." % \
				_name_for(sid, id_to_name))
			break

	return lines

static func _name_for(item_id: String, id_to_name: Dictionary) -> String:
	var name := String(id_to_name.get(item_id, ""))
	if name != "":
		return name
	return item_id
