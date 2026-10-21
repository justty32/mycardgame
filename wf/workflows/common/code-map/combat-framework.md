# code-map／戰鬥框架 — 檔案導航（Phase 3）

[code-map](../code-map.md)｜[spec](../../../specs/combat-framework/README.md)

從 code-map 抽出的戰鬥框架段；維護鏈與真相層優先序照父檔。

## 時間軸與單位

每場開始的解析、裝配與規則資料所有權，見 [每場準備 code map](combat-preparation.md)。

[UnitRegistry.gd](../../../../game/scripts/combat/UnitRegistry.gd)（autoload）管 unit_uid、陣營、主角與 unit_spawned／unit_removed。[CombatDirector.gd](../../../../game/scripts/combat/CombatDirector.gd)（`Global.get_combat_director()`）跑 CTB 行動迴圈與開戰／停止，只經核心 [CombatModule.gd](../../../../game/scripts/combat/CombatModule.gd) 介面呼叫可選模組（不引用棋盤類別），缺模組內容由 [CombatContentRequirements.gd](../../../../game/scripts/combat/CombatContentRequirements.gd) 以資料標記判定；可選 [BoardCombatModule](../../../../game/scripts/combat/board/BoardCombatModule.gd) 由 Combat 場景在檔案存在時以路徑組裝（模組範圍：`combat/board/`、`actions/board_actions/`、`validators/board/`、`ui/Board*.gd`），內部 [BoardController.gd](../../../../game/scripts/combat/board/BoardController.gd) 建棋盤、部署主角、放置單位與點格移動，[UnitSpawner.gd](../../../../game/scripts/combat/UnitSpawner.gd) 生成波次單位（待進場佇列與進場格策略）與棋盤召喚，[WaveController.gd](../../../../game/scripts/combat/WaveController.gd) 管波次開始／清空、下一波排程與勝利判定，[CombatActionPhases.gd](../../../../game/scripts/combat/CombatActionPhases.gd) 是一次行動固定的開始／結束階段，[CombatStartActions.gd](../../../../game/scripts/combat/CombatStartActions.gd) 是開戰前的初始動作；EnemyIntentController 在未掛模組時保留普通意圖，掛載時交 BoardCombatModule／BoardEnemyIntent 執行空間意圖。排序在 [CombatTimeline.gd](../../../../game/scripts/combat/CombatTimeline.gd)，`controllers/` 分玩家與敵人。[CombatEndAction.gd](../../../../game/scripts/ui/CombatEndAction.gd) 等出牌佇列清空後結束行動，[TimelineBar.gd](../../../../game/scripts/ui/TimelineBar.gd) 顯示行動順序。

[BaseCombatant.gd](../../../../game/scripts/combatants/BaseCombatant.gd) 帶單位身分與每次行動的移動計數。[CombatRulesData.gd](../../../../game/data/readonly/CombatRulesData.gd)（`Global.get_combat_rules()`）定節奏與移動規則。

## 棋盤（Phase 2）

`game/scripts/combat/board/` 的核心查詢入口：

- [BoardData.gd](../../../../game/scripts/combat/board/BoardData.gd)：格子、佔格、距離、由 BoardPathfinding 提供加權 Dijkstra 尋路與 NEAREST_EMPTY。
- [BoardTargeting.gd](../../../../game/scripts/combat/board/BoardTargeting.gd)：形狀、陣營與出牌目標檢查，另提供 Validator 的上下文。
- [IntentResolver.gd](../../../../game/scripts/combat/board/IntentResolver.gd)：敵人意圖的目標、預計格與命中。
- [ThreatPreview.gd](../../../../game/scripts/combat/board/ThreatPreview.gd)：預計受傷。

遭遇資料是 [EncounterData.gd](../../../../game/data/readonly/EncounterData.gd)（波次在 embedded/EncounterWaveData.gd），沒有遭遇 id 的事件由它合成；它也負責每盤大小解析與大小／格子驗證（`validate_configuration_detail`，契約見 [棋盤大小](../../../specs/board-module/board-size.md)），上下限在 CombatRulesData。棋盤 Action 在 `game/scripts/actions/board_actions/`（[ActionMoveUnit](../../../../game/scripts/actions/board_actions/ActionMoveUnit.gd)、[ActionDisplaceUnit](../../../../game/scripts/actions/board_actions/ActionDisplaceUnit.gd)、ActionGrantMovePoints、ActionComputeBoardValue），Validator 在 `game/scripts/validators/board/`。

UI 是 [BoardView.gd](../../../../game/scripts/ui/BoardView.gd)，由模組的 [BoardCombatPresentation](../../../../game/scripts/ui/BoardCombatPresentation.gd) 管理格子、角色映射與 Undo。Hand／HandManager 只使用 [CardPlayAdapter](../../../../game/scripts/combat/CardPlayAdapter.gd) 通用 hooks（未掛模組時缺模組的牌變灰並費用前拒絕，原因在 `request.rejection_reason`）；掛載時模組提供的 [BoardCardAdapter](../../../../game/scripts/combat/board/BoardCardAdapter.gd) 與 BoardCardInput 接棋盤目標、預檢、點格與舊欄位轉譯。生成仍經 [EnemyContainer.gd](../../../../game/scripts/ui/EnemyContainer.gd)。

盤集合、部署政策與畫面矩形的獨立接點，見 [盤定義 code map](board-setup.md)。

## 測試

Smoke 呼叫 [unit_registry_probe.gd](../../../../tests/unit_registry_probe.gd)，驗合成遭遇與純棋盤查詢。suite Ctb 跑 [ctb_flow.gd](../../../../tests/ctb_flow.gd) 加 [ctb_fixture.gd](../../../../tests/ctb_fixture.gd)。suite Wave 跑 [wave_flow.gd](../../../../tests/wave_flow.gd)，情境在 [wave_cases.gd](../../../../tests/wave_cases.gd)，fixture 在 [wave_fixture.gd](../../../../tests/wave_fixture.gd)。suite Board 跑 [board_flow.gd](../../../../tests/board_flow.gd)，情境在 [board_cases.gd](../../../../tests/board_cases.gd)，fixture 在 [board_fixture.gd](../../../../tests/board_fixture.gd)；每場棋盤大小與版面數值在 [board_size_cases.gd](../../../../tests/board_size_cases.gd)。

## 雙盤 A 與 Phase 2b

位置與策略由 [BoardPosition](../../../../game/scripts/combat/board/BoardPosition.gd)、[CombatBattlefield](../../../../game/scripts/combat/board/CombatBattlefield.gd)、[CrossBoardPolicy](../../../../game/scripts/combat/board/CrossBoardPolicy.gd) 管理；[BoardActionGeometry](../../../../game/scripts/combat/board/BoardActionGeometry.gd) 集中檢查巢狀動作與費用前拒絕。正常新局預設 DUAL，舊幾何回歸顯式 SINGLE，不能用 faction 取代目前盤身分。

[FieldController](../../../../game/scripts/combat/board/FieldController.gd) 每盤一個；[FieldClockAction](../../../../game/scripts/combat/board/FieldClockAction.gd) 全盤動態補刻，[FieldEventAction](../../../../game/scripts/combat/board/FieldEventAction.gd) 管進出／停留與 owner／generation，[FieldPreview](../../../../game/scripts/combat/board/FieldPreview.gd) 提供純傷害與收益估值。ActionHandler 的 ordered 子樹保留 legacy queue/stack，外部重入與真正子動作分開。

[BoardPathfinding](../../../../game/scripts/combat/board/BoardPathfinding.gd) 管 Dijkstra，[BoardMovementState](../../../../game/scripts/combat/board/BoardMovementState.gd) 管 ZOC 與 undo；[BoardMoveSequence](../../../../game/scripts/actions/board_actions/BoardMoveSequence.gd) 逐格反應，[BoardTransferAction](../../../../game/scripts/actions/board_actions/BoardTransferAction.gd) 原子轉移後發事件。意圖位置接點見 [board-intents](../../../specs/board-module/intents.md)。

[BoardActorPresentation](../../../../game/scripts/ui/BoardActorPresentation.gd) 映射實際 sprite/HUD/hitbox 到兩盤，保留父節點與 UID，動畫位置不回寫資料格。專項為 [Field](../../../../tests/field_flow.gd)、[DualBoard](../../../../tests/dual_board_flow.gd)；需求／測試／證據依 [雙盤矩陣](../../../specs/dual-board/verification.json)。開發流程見 [fields-zoc](../../game-dev/fields-zoc.md)。

可選模組責任及相容界線見 [架構分析](../../../specs/board-module/README.md)。真正未掛模組由 [Boardless](../../../../tests/boardless_flow.gd) 四階段驗證，刪除模組檔的副本由 suite BoardRemoved（同一 boardless 測例的 removed／defeat 階段）驗證；審查回歸在 [review_regression_cases](../../../../tests/review_regression_cases.gd)（Field suite）；中性包的自然三場流程由 [PackScenario](../../../../examples/board-lab/tests/scenario.json) 驗證。
