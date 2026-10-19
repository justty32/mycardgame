# 第一個 mod：從檔案到隔離載入驗收

[內容入口](../content.md)｜[環境](../../dev-env.md)｜[驗證](../../testing.md)

**何時用**：fresh clone 後建立第一個獨立 mod，或要在候選副本試驗教學內容。**何時不用**：單純改既有卡數值回內容入口；新行為原語走 [mechanics](../mechanics.md)。本篇範例是 [新手指南](../../../../analysis/slay-the-robot/tutorial/beginner_guide_zh.md) 的重擊，不代表使用者已選定玩法。

## Done when

mod 三個資料檔與清單登記存在；專屬 helper 已接入既有 suite，其命令 exit 0、有本次斷言與完成標記、無禁止錯誤。這只完成載入驗收；卡牌出牌／預覽／存讀的任務須再取得對應證據。所有命令從本專案根開始，只有取得背景引擎執行授權時才執行測試。

## 準備候選副本

正式實作可直接修改授權中的 game／tests，再由 runner 隔離；若只是試教學、不應改原檔，先在 PowerShell 7 建唯一候選根。以下只複製 game、tools、tests，沒有複製個人存檔、Git 或引擎，也不刪來源。

```powershell
$repoRoot = (Get-Location).Path
$candidateRoot = Join-Path $repoRoot ('artifacts/mod-bootstrap-' + [guid]::NewGuid().ToString('N'))
$candidateGame = Join-Path $candidateRoot 'game'
$enginePath = Join-Path $repoRoot '.tools/godot-4.6/Godot_v4.6-stable_win64_console.exe'
New-Item -ItemType Directory -Path $candidateRoot | Out-Null
$sourceGame = Join-Path $repoRoot 'game'
& robocopy $sourceGame $candidateGame /E /R:0 /W:0 /NFL /NDL /NJH /NJS /NP /XJ /XD .git .godot .import .saves .screenshots (Join-Path $sourceGame 'external/saves') /XF profile.json user_settings.json
if ($LASTEXITCODE -ge 8) { throw 'Candidate game copy failed' }
foreach ($part in @('tools', 'tests')) {
    & robocopy (Join-Path $repoRoot $part) (Join-Path $candidateRoot $part) /E /R:0 /W:0 /NFL /NDL /NJH /NJS /NP /XJ
    if ($LASTEXITCODE -ge 8) { throw "Candidate $part copy failed" }
}
$candidateRoot
```

以下檔案只寫到候選根。內容、fixture 與測試呼叫須在同一副本；來源鎖仍指上游。

## 第一批應寫檔案

依新手指南的三段完整 JSON 建立候選根下 `game/external/mods/mycardgame/mod_info.json`、`cards/card_heavy_strike.json`、`characters/character_red.json`，保留 `properties`／`patch_data` 包裝。卡為費用 2、15 傷害、起手追加一次、暫不進卡包；不要複製官方範例的 script takeover。

`mod_folder_to_load_data` 的 key 相對於 **game 根**，不是相對 mod_info：`external/mods/mycardgame/cards/` 映射 `CardData`／`_id_to_card_data`，`external/mods/mycardgame/characters/` 映射 `CharacterData`／`_id_to_character_data`。檔名不取代 object_id；角色補丁須使用既有 `character_red`。

修改候選 `game/external/mod_list.json`：保留 `external/` 與既有項目，在 `properties.mod_load_data` 新增 `"external/mods/mycardgame/": {"enabled": true, "load_priority": 10}`。priority 升序載入，避免同 priority 的覆寫碰撞。只建資料夾、只登記 schema、或只放卡 JSON 都不足以啟用 mod。

如需求是獎勵取得，先走 [卡牌設計](../card-design.md) 檢查現有 card_pack_red 的篩選；符合紅色／COMMON／ATTACK 且 `card_appears_in_card_packs=true` 的卡可用既有 pack，不必一律新建 pack。以下 probe 刻意限定起手版，改規格時同步改斷言。

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

runner 只接受固定 suite；沒有 `-Suite Mod` 或 `Custom`。它會複製 tests 頂層全部 `.gd`，但不會自動執行新 helper；上述呼叫才建立執行鏈。不要修改 `_finish()` 的 SMOKE PASS 標記或把失敗改成單純 print。

## 實際命令與交付範圍

確認引擎位置後，在同一 PowerShell session 執行候選 runner。暫時將當次程序 APPDATA 指到候選私有目錄，讓 user:// 也留在可寫範圍；finally 還原，不改永久環境設定：

```powershell
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $candidateRoot 'user-data'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    & (Join-Path $candidateRoot 'tools/test-game.ps1') -Suite Smoke -GodotPath $enginePath
}
finally { $env:APPDATA = $previousAppData }
```

日誌位於候選根的 artifacts/verification；讀其 results.json、smoke.log 及 console log。成功需 `completed=true`、`verdict=PASS`、各階段符合 testing 規則，且出現八項 `PASS: MOD:`，不能只看到舊 Smoke PASS。正式接回專案 game／tests 後命令是 `./tools/test-game.ps1 -Suite Smoke`；若另用 `-SourceGame`，tests 仍取執行中 runner 所屬專案，不會跟到候選 game 的旁邊。

runner 的 source_hashes 只涵蓋 13 個框架檔；另記 mod 三檔、mod_list 及修改 tests 的 SHA-256、候選根與日誌。候選與正式檔不一致時不能沿用證據。實作後依內容入口同步文件及 lint；只演練則保留未落地標記。

已有 Combat fixture 會把起始牌組覆寫為五張原生牌，不能證明重擊被使用。出牌需求須在專屬情境中保留新牌，沿 combat_flow 的 `_play()`／等待 idle 檢查費用、合法與拒絕目標、HP／格擋、手牌移動及預覽，再由所接 suite 執行；改牌組後不可照用原生卡 20 傷害的固定勝敗斷言。SaveLoad 同理須明確讓新卡進入存讀快照。完整效果設計與驗收接 [卡牌評量](../card-evaluation.md)。

圖像／UI／音訊 fixture 另依領域流程。headless 不證明畫面正確或音訊無實體輸出；播放測試先隔離音訊裝置。教學手動驗收僅在有效 GUI 授權下執行。

2026-10-19 依上游 4dac5abe 加本地修復核對；後續候選 Smoke 為 52／0，八項新斷言均執行。首次失敗、重試證據與未驗範圍見 [實跑分析](../../../../analysis/slay-the-robot/design/mod-bootstrap.md)，不代表正式遊戲已加入此 mod。
