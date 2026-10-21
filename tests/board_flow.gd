extends SceneTree
## Combat framework Phase 2: board, movement, range / shape cards and intent movement.
## Run ONLY with --path pointing to an isolated copy (tools/test_game.py --suite Board).
## Drives the real Root scene, New Run menu and map into a 7x5 board encounter; input goes through
## the Hand / BoardView signal handlers (card_selected, cell_clicked) and End Turn. Test-only unit
## placement uses BoardData.move (documented per case). Mouse hit-testing is not covered.

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
	print("BOUNDARY: one board combat with declared data fixtures; UI handler/signals, not mouse coordinates; test-only placement through BoardData.move; the combat is left unfinished and the scene freed.")
	var size_cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("board_size_cases.gd")).new()
	size_cases.run(self)
	load(get_script().resource_path.get_base_dir().path_join("board_setup_cases.gd")).new().run(self)
	load(get_script().resource_path.get_base_dir().path_join("multi_board_module_cases.gd")).new().run(self)
	var cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("board_cases.gd")).new()
	var completed: bool = await cases.run(self)
	_check(completed, "complete board scenario returned")
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
		var report: FileAccess = FileAccess.open(output_directory.path_join("board-result.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"checks": checks, "failures": failures, "assertions": results, "boundary": "one unfinished board combat, declared data fixture, real UI signals/handlers; no physical mouse hit testing"}, "\t"))
	print("BOARD %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _timeout() -> void:
	if not finished:
		_check(false, "150-second overall timeout")
		_finish()
