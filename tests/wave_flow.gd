extends SceneTree
## Combat framework Phase 3: waves (wave_started / wave_cleared, enter delays, spawn policies, minions, victory).
## Run ONLY with --path pointing to an isolated copy (tools/test_game.py --suite Wave).
## Drives the real Root scene, New Run menu and map into a three-wave encounter; input goes through
## the Hand / BoardView signal handlers (card_selected, cell_clicked) and End Turn. The combat is won
## through the real victory path (last wave cleared). Mouse hit-testing is not covered.

var checks: int = 0
var failures: int = 0
var finished: bool = false
var results: Array[Dictionary] = []
var output_directory: String


func _initialize() -> void:
	call_deferred("_main")


func _main() -> void:
	create_timer(150.0).timeout.connect(_timeout)
	output_directory = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/").get_base_dir()
	if not _check(output_directory.replace("\\", "/").contains("/artifacts/"), "project is in an isolated artifacts copy"):
		_finish()
		return
	print("BOUNDARY: one three-wave combat with declared data fixtures; UI handler/signals, not mouse coordinates; the combat ends through the real victory path and the scene is freed.")
	var cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("wave_cases.gd")).new()
	var completed: bool = await cases.run(self)
	_check(completed, "complete wave scenario returned")
	await cases.free_scene()
	_check(root.get_node("Global").get_combat_director() == null, "freed run screen leaves no combat director behind")
	_finish()


func _check(condition: bool, label: String) -> bool:
	checks += 1
	results.append({"pass": condition, "label": label})
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)
	return condition


func _finish() -> void:
	if finished:
		return
	finished = true
	if output_directory != "" and output_directory.replace("\\", "/").contains("/artifacts/"):
		var report: FileAccess = FileAccess.open(output_directory.path_join("wave-result.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"checks": checks, "failures": failures, "assertions": results, "boundary": "one three-wave combat won through the real victory path, declared data fixture, real UI signals/handlers; no physical mouse hit testing"}, "\t"))
	print("WAVE %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _timeout() -> void:
	if not finished:
		_check(false, "150-second overall timeout")
		_finish()
