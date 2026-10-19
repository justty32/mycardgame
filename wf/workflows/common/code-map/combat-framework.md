# code-map／戰鬥框架 — 檔案導航（Phase 2）

[code-map](../code-map.md)｜[spec](../../../specs/combat-framework/README.md)｜[Phase 2 plan](../../../plans/combat-framework/phase-2.md)

從 code-map 抽出的戰鬥框架段；維護鏈與真相層優先序照父檔。

## 時間軸與單位

[UnitRegistry.gd](../../../../game/scripts/combat/UnitRegistry.gd)（autoload）管 unit_uid、陣營、主角與 unit_spawned／unit_removed。[CombatDirector.gd](../../../../game/scripts/combat/CombatDirector.gd)（`Global.get_combat_director()`）跑 CTB 行動迴圈，Phase 2 起也負責開戰建棋盤、生成第 0 波、移動點與付費移動、敵人意圖移動。排序在 [CombatTimeline.gd](../../../../game/scripts/combat/CombatTimeline.gd)，`controllers/` 分玩家與敵人。[CombatEndAction.gd](../../../../game/scripts/ui/CombatEndAction.gd) 等出牌佇列清空後結束行動，[TimelineBar.gd](../../../../game/scripts/ui/TimelineBar.gd) 顯示行動順序。

[BaseCombatant.gd](../../../../game/scripts/combatants/BaseCombatant.gd) 帶單位身分與每次行動的移動計數。[CombatRulesData.gd](../../../../game/data/readonly/CombatRulesData.gd)（`Global.get_combat_rules()`）定節奏與移動規則。

## 棋盤（Phase 2）

`game/scripts/combat/board/` 下有四支：

- [BoardData.gd](../../../../game/scripts/combat/board/BoardData.gd)：格子、佔格、距離、BFS 尋路與 NEAREST_EMPTY。
- [BoardTargeting.gd](../../../../game/scripts/combat/board/BoardTargeting.gd)：形狀、陣營與出牌目標檢查，另提供 Validator 的上下文。
- [IntentResolver.gd](../../../../game/scripts/combat/board/IntentResolver.gd)：敵人意圖的目標、預計格與命中。
- [ThreatPreview.gd](../../../../game/scripts/combat/board/ThreatPreview.gd)：預計受傷。

遭遇資料是 [EncounterData.gd](../../../../game/data/readonly/EncounterData.gd)（波次在 embedded/EncounterWaveData.gd），沒有遭遇 id 的事件由它合成。棋盤 Action 在 `game/scripts/actions/board_actions/`（[ActionMoveUnit](../../../../game/scripts/actions/board_actions/ActionMoveUnit.gd)、[ActionDisplaceUnit](../../../../game/scripts/actions/board_actions/ActionDisplaceUnit.gd)、ActionGrantMovePoints、ActionComputeBoardValue），Validator 在 `game/scripts/validators/board/`。

UI 是 [BoardView.gd](../../../../game/scripts/ui/BoardView.gd)，由 Combat 在執行時建立的自繪格子。[Hand.gd](../../../../game/scripts/ui/Hand.gd) 把 `cell_clicked` 轉成出牌目標或移動；生成仍經 [EnemyContainer.gd](../../../../game/scripts/ui/EnemyContainer.gd)。

## 測試

Smoke 呼叫 [unit_registry_probe.gd](../../../../tests/unit_registry_probe.gd)，驗合成遭遇與純棋盤查詢。suite Ctb 跑 [ctb_flow.gd](../../../../tests/ctb_flow.gd) 加 [ctb_fixture.gd](../../../../tests/ctb_fixture.gd)。suite Board 跑 [board_flow.gd](../../../../tests/board_flow.gd)，情境在 [board_cases.gd](../../../../tests/board_cases.gd)，fixture 在 [board_fixture.gd](../../../../tests/board_fixture.gd)。
