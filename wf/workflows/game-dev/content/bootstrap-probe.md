# 第一個 mod：probe、命令與交付範圍

[第一個 mod](bootstrap.md)｜[內容入口](../content.md)｜[驗證](../../testing.md)

**何時用**：已照 [第一個 mod](bootstrap.md) 在候選根寫好 mod 檔與清單登記，要把載入斷言接進 Smoke 並實際執行。

**何時不用**：題材樹的內容包改用 runner 的 `--pack`／`--pack-tests` 與 PackScenario，見 [題材內容包](pack.md)；要驗出牌效果，接 [卡牌評量](../card-evaluation.md) 的專項情境。

## 測試 helper 接入既有 suite

新增候選 `tests/mod_bootstrap_probe.gd`。範例使用已有 autoload 的實際資料，不另外呼叫 FileLoader 重載，以免 append 重複。它只驗註冊、欄位與起手引用，不冒充 action 執行。

```gdscript
extends RefCounted

func check_loaded(global_data: Node) -> Dictionary:
    var result: Dictionary = {}
    var card: Resource = global_data.get_card_data("card_heavy_strike")
    var character: Resource = global_data.get_character_data("character_red")
    result["MOD: heavy strike registered"] = card != null
    result["MOD: red character registered"] = character != null
    if card == null or character == null:
        return result
    result["MOD: starting deck contains one heavy strike"] = character.character_starting_card_object_ids.count("card_heavy_strike") == 1
    result["MOD: existing basic attacks retained"] = character.character_starting_card_object_ids.count("card_attack_basic") == 3
    result["MOD: existing basic blocks retained"] = character.character_starting_card_object_ids.count("card_block_basic") == 3
    result["MOD: declared cost and damage"] = card.card_energy_cost == 2 and card.card_values.get("damage") == 15
    result["MOD: starting-only card"] = not card.card_appears_in_card_packs
    result["MOD: attack action reference"] = card.card_play_actions.size() == 1 and card.card_play_actions[0].has("res://scripts/actions/combatant_actions/ActionAttackGenerator.gd")
    return result
```

在候選 [framework_smoke.gd](../../../../tests/framework_smoke.gd) 的 `_run()`，既有起手 ID 解析迴圈**之後**、`_check_array_patch()`／`_check_example_mod()` **之前**插入以下區塊；使用原函式的 tab 縮排。這裡 autoload 已 ready，官方 example probe 尚未再次改角色資料。

```gdscript
    var mod_probe: RefCounted = load(get_script().resource_path.get_base_dir().path_join("mod_bootstrap_probe.gd")).new()
    var mod_results: Dictionary = mod_probe.check_loaded(global_data)
    for label: String in mod_results:
        _check(mod_results[label], label)
```

框架 suite 會複製 tests 頂層全部 `.gd`，但不會自動執行新 helper；上述呼叫才建立執行鏈。可重用的內容包完整流程改走 PackScenario 與 scenario manifest（見 [內容包](pack.md)），沒有任意 `Mod`／`Custom` suite。不要修改 `_finish()` 的 SMOKE PASS 標記或把失敗改成單純 print。

## 實際命令與交付範圍

以候選根自己的 runner 執行（`<candidateRoot>` 換成 [準備候選副本](bootstrap.md#準備候選副本) 印出的路徑）。引擎省略時由 runner 探測；候選根沒有 `.tools/`，引擎不在 PATH（例如 Windows 的可攜版）就加 `--godot-path`。user:// 與 APPDATA／XDG 目錄由 runner 導到該次 run 目錄，不必手動改環境變數：

```bash
python3 <candidateRoot>/tools/test_game.py --suite Smoke --project-root <candidateRoot>
```

日誌位於候選根的 artifacts/verification；讀其 results.json、smoke.log 及 console log。成功需 `completed=true`、`verdict=PASS`、各階段符合 testing 規則，且出現八項 `PASS: MOD:`，不能只看到舊 Smoke PASS。正式接回專案 game／tests 後命令是 `python3 tools/test_game.py --suite Smoke`；若另用 `--source-game`，tests 仍取執行中 runner 所屬專案，不會跟到候選 game 的旁邊。

runner 的 source_hashes 涵蓋 SOURCE_HASH_PATHS 指定的框架核心檔，並非所有內容檔；另記 mod 三檔、mod_list 及修改 tests 的 SHA-256、候選根與日誌。候選與正式檔不一致時不能沿用證據。實作後依內容入口同步文件及 lint；只演練則保留未落地標記。

已有 Combat fixture 會把起始牌組覆寫為五張原生牌，不能證明重擊被使用。出牌需求須在專屬情境中保留新牌，沿 combat_flow 的 `_play()`／等待 idle 檢查費用、合法與拒絕目標、HP／格擋、手牌移動及預覽，再由所接 suite 執行；改牌組後不可照用原生卡 20 傷害的固定勝敗斷言。SaveLoad 同理須明確讓新卡進入存讀快照。完整效果設計與驗收接 [卡牌評量](../card-evaluation.md)。

圖像／UI／音訊 fixture 另依領域流程。headless 不證明畫面正確或音訊無實體輸出；播放測試先隔離音訊裝置。教學的手動驗收需要 GUI，未執行時標為未驗。

2026-10-19 依上游 4dac5abe 加本地修復核對；後續候選 Smoke 為 52／0，八項新斷言均執行（當時為 Godot 4.6 與 PowerShell 候選流程；4.7 尚未重跑）。首次失敗、重試證據與未驗範圍見 [實跑分析](../../../../analysis/slay-the-robot/design/mod-bootstrap.md)，不代表正式遊戲已加入此 mod。
