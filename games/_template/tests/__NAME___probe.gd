extends RefCounted
# 題材 probe：驗內容包已載入。由 Smoke 經 runner 的 --pack/--pack-tests 呼叫。
# 斷言標籤須以題材前綴開頭（大寫），新增卡後在此補斷言。

func check_loaded(global_data: Node) -> Dictionary:
	var result: Dictionary = {}
	result["__PREFIXUP__: base color registered"] = global_data.get_color_data("__PREFIX__color_base") != null
	return result
