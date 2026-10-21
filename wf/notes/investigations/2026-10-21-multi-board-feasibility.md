# 多棋盤（3 盤以上／數量由遭遇資料決定）可行性調查：現況

> 狀態：2026-10-21 唯讀調查，尚待使用者決定多盤玩法語意，未實作。續篇（語意模型與推薦方案）：[models](2026-10-21-multi-board-models.md)。

日期：2026-10-21｜基準：main @ bc7fe2d｜方式：唯讀靜態讀碼，未跑 Godot、未改檔。

## 問題

戰鬥能否支援 3 盤以上、或盤數由每場戰鬥資料決定？哪些層已是 N 盤通用、哪些寫死兩盤；有哪些可行語意模型、各自代價；最小可行方案是什麼。

## 方法

讀過：AGENTS.md、wf/WORKFLOWS.md、common/user.md、agent-session.md、investigation.md、code-map.md、decisions.md／decisions.json（棋盤相關 7 列）、wf/specs/dual-board/{README,presentation}.md、wf/specs/board-module/{README,board-size,intents}.md。
原始碼：`game/scripts/combat/board/*`（CombatBattlefield、BoardController、BoardCombatModule、CrossBoardPolicy、BoardTargeting、BoardActionTargets、BoardActionGeometry、FieldActionCells、IntentResolver、ThreatPreview、BoardCardInput、BoardMovementState）、`game/scripts/ui/BoardCombatPresentation.gd`、`BoardView.gd`、`game/data/readonly/{EncounterData,CombatRulesData}.gd`、`UnitSpawner.gd`；`rg` 搜 `"party"|"enemy"|"shared"`、`BOARD_MODES`、`default_board_id`、`boards.size()` 於 game/、tests/、examples/board-lab/。

## 發現

### 1. 已是 N 盤通用（依 board_id 運作，不假設只有兩盤）

層｜位置｜說明

建盤迴圈｜CombatBattlefield.gd:33-38｜對 `encounter.get_board_ids()` 每個 id 建 BoardData；`boards` 是 `Dictionary[String, BoardData]`（:11）

單位查詢／放置／轉移／交換｜CombatBattlefield.gd:45-146｜以 `unit.board_id`、`destination.board_id` 查盤；transfer/swap 只快照涉及的 1～2 盤，原子性與盤數無關

跨盤規則 A｜CrossBoardPolicy.gd:17-34｜`cross_board = source.board_id != target.board_id`；任兩盤之間都適用 A（無距離、方向型拒絕、形狀在目標盤展開）。**規則 A 本身天然支援 N 盤**

場域與時鐘｜BoardController.gd:9, 28-31, 132-136｜每盤一個 FieldController；FieldClockAction 一次排序所有 controllers

借機（ZOC）去重｜BoardController.gd:27-29；BoardMovementState.gd:52｜共享 used_opportunities；ZOC 判斷只看本盤敵對單位

敵人目標選擇｜IntentResolver.gd:11-51, 126-129｜候選取自整個 battlefield；同盤可比距離優先，否則以 uid 穩定 fallback——N 盤可直接沿用

威脅預覽｜ThreatPreview.gd:17-28, 37-49｜每敵人用自己實際盤解析；hazard／借機用單位所在盤

卡牌選盤｜BoardCardInput.gd:41-58；BoardCardAdapter.gd:50, 123-143；BoardTargeting.gd:221-225；FieldActionCells.gd:7-17｜一律寫入／讀取 `selected_board_id`，或用施法者實際盤

範圍類 override｜BoardActionTargets.gd:44-63｜UNITS_IN_RANGE 只看 parent 所在盤；UNITS_ON_FIELD 看解析出的盤

生成｜UnitSpawner.gd:63-81, 107, 148, 167；BoardCombatModule.gd:186-216｜波次條目帶 board_id；放置 hooks 以 zone_id＝board_id 查盤

呈現建 view｜BoardCombatPresentation.gd:47-76｜對 `battlefield.boards.keys()` 每盤建 BoardView，`_view_board_ids` 只做變更偵測

移動訊號｜Signals.gd:174｜`unit_board_moved(from_board_id, to_board_id)` 帶盤名

存讀檔｜spec dual-board README「位置、陣營與戰鬥」｜不存戰中盤，從 Encounter 重建——盤數由資料決定即可

### 2. 寫死兩盤（或 SINGLE/DUAL 二選一）的地方

#｜位置｜寫死內容｜多盤時的問題

H1｜CombatRulesData.gd:20 `enum BOARD_MODES {SINGLE, DUAL}`；:101 驗證｜只有兩種模式｜新模式會被 `unknown_board_mode` 拒絕

H2｜EncounterData.gd:48-52 `get_board_ids`｜SINGLE→`["shared"]`，DUAL→`["party","enemy"]`｜盤名清單寫死，無從資料決定盤數

H3｜EncounterData.gd:85-90｜模式白名單；`encounter_boards` 鍵必須在 allowed 內｜額外盤名被 `invalid_encounter_board` 拒絕

H4｜EncounterData.gd:116 `default_wave_board = allowed[size-1]`｜「最後一盤＝敵方盤」的隱含假設｜與 BoardCombatModule.gd:192 的 `default_board_id(ENEMY)` 只在 DUAL 巧合一致；N 盤會分歧

H5｜CombatBattlefield.gd:7-9 常數；:63-66 `default_board_id(faction)`｜PARTY→`party`，其餘（含 NEUTRAL）→`enemy`｜陣營→主場盤是硬編碼二分

H6｜BoardController.gd:11-13 舊 `board` getter；:54 主角 home；:80-81 `default_deploy_cells("")` 用 party 盤；:89-93 `default_spawn_origin("")` 用 enemy 盤｜經 H5 推導｜多盤時需「哪一盤是主角部署盤／預設生成盤」的資料來源

H7｜BoardCombatModule.gd:190-192 `resolve_spawn_location`｜無 board_id 的波次條目→enemy 盤｜同 H4

H8｜BoardCombatPresentation.gd:15-22 `DUAL_SLOT_ORIGINS`（2 個槽）、`view_position` 以 `clampi(index, 0, 1)`｜第 3 盤起**與第 2 盤疊在同一槽**｜版面直接壞；需 N 槽排版

H9｜BoardView.gd:7 `PANEL_MAX_SIZE 460×280`；:6 `PANEL_POSITION`｜槽寬以「兩盤左右並列」推出｜3 盤並列每槽約 ≤340 px 寬，12 列時格寬 < 23 px；與 board-size 上限的前提衝突

H10｜CombatBattlefield.gd:41 起 `BaseCombatant.board_id = "shared"`（BaseCombatant.gd:41、BoardData.gd:12、BoardView.gd:24）｜預設值｜無害，僅預設

H11｜測試：tests/dual_board_fixture.gd:10-21、combat_flow.gd:134、save_load_flow.gd:176、dual_board_cases.gd:18、dual_board_presentation_cases.gd:220（`boards.size()==2`）；`"party"/"enemy"` 散佈於 15 個測試檔（board_size_cases 26 處、dual_board_field 25、presentation 20、transfer 19…）｜斷言兩盤｜DUAL 保留不變則這些仍有效；N 盤需新 fixture，不必改舊斷言

H12｜示範包 examples/board-lab/pack/encounters/*.json、cards/demo_cross_step.json、tests/scenario_*.gd｜用 party/enemy 盤名｜DUAL 保留即不受影響

結論：**寫死集中在「盤清單從哪來」（H1-H4）、「陣營→主場盤」（H5-H7）、「版面槽」（H8-H9）三處**；規則、AI、ZOC、場域、選盤、原子轉移都已以 board_id 運作。

### 3. 次要觀察

`ALL` shape 只含選定盤、`ALL_OPPONENTS` 是全戰場（spec dual-board README）——N 盤時語意不變，但「全體敵人」是否該跨所有敵方盤需在內容層說清楚（現行即跨全部）。

普通步行不跨盤（BoardController.gd:115-129 只在本盤 reachable）；跨盤只能 TELEPORT／DisplaceUnit／SWAP（BoardActionGeometry.gd:64-80）——N 盤時玩家「換盤」全靠特殊卡，可能造成多盤戰鬥中主角無法接觸遠端盤，屬玩法而非技術問題。

AI 在沒有同盤目標時 NEAREST/FARTHEST 以 uid fallback（IntentResolver.gd:29-34）；多個敵方盤時，大部分敵人都會落入 fallback，「最近」失去意義（技術上不壞，設計上需知悉）。

雙盤時主角只部署在 party 盤（BoardController.gd:52-59）；隊伍目前只有主角一人入盤。

