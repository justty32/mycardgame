extends SceneTree
## Run via tools/test-game.ps1; the helper is loaded AFTER singleton registration.
var checks := 0
var failures := 0
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(45).timeout.connect(func(): printerr("RESOURCE FAIL: timeout"); quit(124))
	if not ProjectSettings.globalize_path("res://").replace("\\", "/").contains("/artifacts/"):
		printerr("RESOURCE FAIL: requires isolated project")
		quit(1)
		return
	var helper: RefCounted = load(get_script().resource_path.get_base_dir().path_join("resource_lifecycle_cases.gd")).new()
	await helper.run(self, _check)
	helper = null
	await process_frame
	var destination := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("resource-result.json")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "assertions": records}, "\t"))
	file.close()
	print("RESOURCE %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	records.append({"passed": condition, "label": label})
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)
