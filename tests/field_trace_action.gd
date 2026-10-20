extends BaseAction
## Test-only instrumentation for observable ordering of otherwise independent field payloads.

func perform_action() -> void:
	var trace: Array = Global.get_meta("field_test_trace", [])
	trace.append(str(get_action_value("label", "")))
	Global.set_meta("field_test_trace", trace)
