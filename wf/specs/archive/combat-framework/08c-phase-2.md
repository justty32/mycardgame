> 封存 2026-10-21，由 已完成（Phase 2）；後續由 wf/specs/dual-board/README.md、wf/specs/board-module/README.md 延伸 取代

# 分階段計畫（§5）：Phase 2 棋盤 + 移動 + 範圍／形狀卡

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 2：棋盤 + 移動 + 範圍／形狀卡

可玩：主角在 5×5 移動並用射程卡。

### 改動

新 `BoardData.gd`、`BoardTargeting.gd`（shape 純函式）、`BoardView.tscn/gd`、`BoardCell.tscn/gd`、`ThreatPreview.gd`、`ActionMoveUnit.gd`（Scripts 常數）；`EncounterData.gd` + `EncounterWaveData.gd`（本階段只用第 0 波）+ SCHEMA；`EventData` + `event_encounter_object_id` 與合成器；`EnemyContainer` 改為 `UnitLayer`（生成改走 Director）；`EnemyData` + footprint/move/ignores_occupancy；`EnemyIntentData` + range/shape/target_rule/move；`CardData` + range/shape/faction/move_distance；`CardPlayRequest` + acting_unit/selected_cell/resolved_targets；`Hand` 的選目標（現 `_on_enemy_clicked`／`_on_cell_clicked`）改以 `cell_clicked` 選目標、`TargetPreview`；`HandManager._play_card` 以 resolved_targets 建動作；`BaseAction.TARGET_OVERRIDES` 新值；`Enemy.update_enemy_intent` 用 intended_target；`Player.update_incoming_damage_amount` 改 ThreatPreview；`ActionSummonEnemies` 改成「指定格或最近空格」。

**移動增補（詳見 [11-movement-active.md](11-movement-active.md) 起）**：`CombatRulesData` 尾端 `move_adjacency`／`move_split_allowed`／`paid_move_max_cells`／`move_pass_through_allies`／`move_pass_through_enemies`／`displace_tie_axis`／`displace_max_footprint_area`；`BaseCombatant` + `move_points`／`cells_moved_this_action`／`cells_displaced_this_action`／`action_extra_delay`／`ignores_occupancy`／`is_immovable`；`CharacterData` + `character_ignores_occupancy`／`character_is_immovable`，`EnemyData` + `enemy_is_immovable`；`BoardCellData` + `is_blocked`，`EncounterData` + `encounter_blocked_cells`／`encounter_spawn_zone_cells`；`BoardData.reachable_cells` 回傳格→路徑並支援障礙與 footprint、`find_path`；新 `game/scripts/actions/board_actions/ActionMoveUnit.gd`（TO_CELL／TOWARD／AWAY／TELEPORT）、`ActionDisplaceUnit.gd`（PUSH／PULL／PULL_ADJACENT／SWAP，碰撞停住與 `collision_damage_per_cell`）、`ActionGrantMovePoints.gd`、`ActionComputeBoardValue.gd`；新 `game/scripts/validators/board/` 的 `ValidatorDistance`、`ValidatorCellsMoved`、`ValidatorInLine`、`ValidatorPathExists`、`ValidatorCellFree`；`EnemyIntentData.enemy_intent_move` 尾端 `KEEP_RANGE`／`CHARGE` + `enemy_intent_move_distance`／`enemy_intent_preferred_range`；新 `IntentResolver.gd`（純函式，ThreatPreview 與 BoardView 共用，含 `planned_move_cell`）；`CombatDirector` 於主角／AI 隊員行動開始（`_begin_party_action`）重設移動點、`_compute_action_delay` 把 `action_extra_delay` 併入延遲（整合修訂：對照 Phase 1 實作的 Director 結構）；`BoardView` 可達格高亮（免費／付費兩色）、路徑線、敵人預計移動幽靈；`GlobalTestDataGenerator` + `status_rooted`、`card_test_dash_strike`／`card_test_shove`／`card_test_blink`、`enemy_test_charger`（CHARGE）、`enemy_test_archer`（KEEP_RANGE 3）、`combat_rules_default` 不改（免費移動仍 0；Board suite 的 fixture 以 patch 設 `free_move_per_action=1`、`paid_move_max_cells=2`、`extra_move_delay_per_cell=20`）。

**修訂（實作 Phase 2）**：棋盤純函式落在 `game/scripts/combat/board/`（BoardData、BoardCellData、BoardTargeting、IntentResolver、ThreatPreview）；BoardView 為 Combat 執行時建立的自繪 Control（不做 BoardView.tscn／BoardCell.tscn，Root.tscn 不動），戰鬥者圖像留在原畫面位置、棋盤只畫代表方塊；EnemyContainer 不改名 UnitLayer，生成由 Director 呼叫其 `spawn_event_enemy`／`spawn_board_enemy`；BoardView 點到佔格單位時不同時發 `enemy_clicked`（避免重複出牌），改由 Hand 把 `enemy_clicked` 轉成點格；`reachable_cells` 只做四向 BFS（`move_cost`／八向／穿越／撤銷留 2b，EIGHT 暫退四向）；IntentResolver 的 FLANK→APPROACH、TELEPORT→HOLD、目標規則 RANDOM／MARKED→HERO，CHARGE 未對齊直接 APPROACH，打不到的攻擊跳過並保留意圖；ThreatPreview 每個敵人只計一次當前意圖（在目標下次行動前行動者）；ValidatorDisplaceable 改為 `ActionDisplaceUnit.is_displaceable`，ActionDisplaceUnit 另加 TO_CELL；框架測試卡依 ActionHandler 後進先出反向列 `card_play_actions`，攻擊條件用 ActionValidator 包住（框架無 `action_validators` 鍵）；`card_move_distance` 對 EMPTY_CELL 牌為 TO_CELL、其他為 TOWARD；舊 TARGET_OVERRIDES 語意不改，新增 ALL_OPPONENTS；召喚改延遲一幀入列（修 Phase 1 `unit_spawned` 早於 Enemy.init 的潛在錯誤）；完整偏差見 [phase-2-deviations.json](../../plans/combat-framework/phase-2-deviations.json)。

### 規模與風險

規模：~1200 行；20 檔 + Root.tscn；移動增補：原 ~1200 行 → ~1700 行；20 檔 → 27 檔。

風險：高：目標選擇 UI 流程改動最大；大型單位佔格與距離定義要先固定；`example_mod` 的卡沒有 range（-1 = 不檢查）必須仍可玩；移動增補：付費移動把延遲「相加」而非取 max，需在 `_compute_action_delay` 單點處理並在 ctb_flow 補一個斷言；`ActionDisplaceUnit` 必須在單位 `tree_exiting`／倒下後安全（targets 已不在棋盤則跳過）。

### agent

普通（opus）：BoardTargeting／意圖解析／Hand 目標流程；普通（opus）：BoardView/BoardCell UI；雜活：資料欄位與 SCHEMA；移動增補：普通（opus）：`reachable_cells`／`IntentResolver`／`ActionDisplaceUnit` 碰撞規則；普通（opus）：BoardView 預覽與幽靈；雜活（sonnet）：欄位、Validator、測試資料。

Done when（13 條移動增補驗收）見 [08d-phase-2-done-when.md](08d-phase-2-done-when.md)。
