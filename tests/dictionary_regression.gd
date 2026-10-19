extends SceneTree
## Run only against an isolated, imported project with --path and --script.

var checks: int = 0
var failures: int = 0
var finished: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30.0).timeout.connect(_timeout)
	var original: Dictionary = {"existing": 3, "shared": 1}
	var incoming: Dictionary = {"added": 5, "shared": 9}
	var cases: Array = [
		["merge_keep", original, incoming, {"existing": 3, "shared": 1, "added": 5}],
		["merge_overwrite", original, incoming, {"existing": 3, "shared": 9, "added": 5}],
		["overwrite", original, incoming, incoming],
		["unknown_strategy", original, incoming, incoming],
		["", original, incoming, incoming],
		["erase", original, {"shared": 0, "missing": 0}, {"existing": 3}],
		["merge_keep", original, {}, original],
		["merge_overwrite", {}, incoming, incoming],
		["overwrite", original, {}, {}],
		["merge_keep", {"nil": null}, {"nil": 7, "new": null}, {"nil": null, "new": null}],
		["merge_overwrite", {"shared": {"old": 1}}, {"shared": {"new": 2}}, {"shared": {"new": 2}}],
		["merge_keep", {"shared": {"old": 1}}, {"shared": {"new": 2}}, {"shared": {"old": 1}}],
	]
	for i: int in range(cases.size()):
		var c: Array = cases[i]
		_check(_dictionary_case(c[0], c[1], c[2], c[3], str(i)) == true, "dictionary case completed " + str(i))
	_check(_typed_dictionary_case() == true, "typed dictionary and JSON roundtrip completed")
	_check(_array_cases() == true, "unchanged Array cases completed")
	_finished()


func _dictionary_case(strategy: String, initial: Dictionary, patch: Dictionary, expected: Dictionary, label: String) -> bool:
	var card: Resource = load("res://data/prototype/CardData.gd").new()
	card.card_values = initial.duplicate(true)
	var old_reference: Dictionary = card.card_values
	var payload: Dictionary = {"properties": {"card_values": patch}, "patch_data": {}}
	if strategy != "":
		payload.patch_data["card_values"] = strategy
	# Exercise the public JSON patch entry point with actual parsed JSON.
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(payload))
	var before: Dictionary = decoded.duplicate(true)
	card.set_serializable_properties_from_json_patch(decoded)
	# JSON numbers decode to floats; compare normalized JSON semantics, not int/float identity.
	var actual_json: Dictionary = JSON.parse_string(JSON.stringify(card.card_values))
	var expected_json: Dictionary = JSON.parse_string(JSON.stringify(expected))
	_check(actual_json == expected_json, "case %s %s: expected %s, got %s" % [label, strategy, JSON.stringify(expected), JSON.stringify(card.card_values)])
	_check(old_reference == initial and decoded == before, "case %s leaves prior dictionary and patch input unchanged" % label)
	return true


func _typed_dictionary_case() -> bool:
	var stats: Resource = load("res://data/mutable/RunStatsData.gd").new()
	stats.run_total_stats.assign({"existing": 3, "shared": 1})
	var payload: Dictionary = JSON.parse_string('{"properties":{"run_total_stats":{"added":5,"shared":9}},"patch_data":{"run_total_stats":"merge_keep"}}')
	stats.set_serializable_properties_from_json_patch(payload)
	_check(stats.run_total_stats == {"existing": 3, "shared": 1, "added": 5}, "typed Dictionary[String, int] merge_keep")
	_check(stats.run_total_stats.is_typed() and stats.run_total_stats.get_typed_key_builtin() == TYPE_STRING and stats.run_total_stats.get_typed_value_builtin() == TYPE_INT, "typed dictionary preserves key and value types")
	payload.patch_data.run_total_stats = "merge_overwrite"
	stats.set_serializable_properties_from_json_patch(payload)
	_check(stats.run_total_stats == {"existing": 3, "shared": 9, "added": 5}, "typed dictionary merge_overwrite")
	var restored: Resource = load("res://data/mutable/RunStatsData.gd").new()
	restored.set_serializable_properties_from_json_patch(JSON.parse_string(JSON.stringify(stats.get_serializable_properties_to_json_patch())))
	_check(restored.run_total_stats == stats.run_total_stats, "patched typed dictionary survives serialized JSON roundtrip")
	return true


func _array_cases() -> bool:
	var cases: Array = [
		["append", ["a", "b", "b", "c"]],
		["append_uniques", ["a", "b", "c"]],
		["erase", ["a"]],
		["overwrite", ["b", "c"]],
		["unknown_strategy", ["b", "c"]],
	]
	for c: Array in cases:
		var character: Resource = load("res://data/readonly/CharacterData.gd").new()
		character.character_starting_card_object_ids.assign(["a", "b"])
		var payload: Dictionary = {"properties": {"character_starting_card_object_ids": ["b", "c"]}, "patch_data": {"character_starting_card_object_ids": c[0]}}
		character.set_serializable_properties_from_json_patch(JSON.parse_string(JSON.stringify(payload)))
		_check(character.character_starting_card_object_ids == c[1], "Array[String] unchanged strategy " + c[0])
	return true


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)


func _finished() -> void:
	finished = true
	print("DICTIONARY %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _timeout() -> void:
	if not finished:
		printerr("DICTIONARY FAIL: timeout")
		quit(124)

