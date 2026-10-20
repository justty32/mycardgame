extends SceneTree
## Phase 2b integration. Use only the isolated headless runner's Field suite.

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
	if not _check(output_directory.replace("\\", "/").contains("/artifacts/"), "Field uses an isolated artifacts copy"):
		_finish()
		return
	print("BOUNDARY: real Root run and handler actions; placement/rule changes are declared fixture setup; no screen, keyboard, mouse or GUI operations.")
	var cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("field_cases.gd")).new()
	_check(await cases.run(self), "complete Field scenario returned")
	await cases.free_scene()
	_check(root.get_node("Global").get_combat_director() == null, "Field run exit releases the director")
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
	if output_directory.replace("\\", "/").contains("/artifacts/"):
		var report := FileAccess.open(output_directory.path_join("field-result.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"checks": checks, "failures": failures, "assertions": results, "boundary": "isolated headless integration; no physical input or rendering verification"}, "\t"))
	print("FIELD %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _timeout() -> void:
	if not finished:
		_check(false, "150-second Field timeout")
		_finish()
