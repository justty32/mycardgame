> 封存 2026-10-21，由 已完成（Phase 2 Done when 全數驗收）；現況見 wf/specs/board-module/README.md 取代

# 分階段計畫（§5）：Phase 2 Done when

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 2 Done when

新 `tests/board_flow.gd`（suite `Board`）：7×5 遭遇、主角移動 1 格後距離正確、`card_range=1` 對距離 2 的目標被拒、CROSS 形狀命中 3 單位、LINE_PIERCE 穿透、2×2 敵人佔 4 格且任一格都可選、敵人 APPROACH 後命中、`ThreatPreview` 數值等於實際受傷；`Smoke` 驗 legacy 事件（無 encounter id）自動合成；`--suite All` 綠；移動增補（`tests/board_flow.gd`，suite `Board`，fixture 7×5、主角在 (3,4)）：

（1）行動開始 `move_points == 1`；點擊距離 1 空格 → `unit_moved` 一次、`move_points == 0`、`cells_moved_this_action == 1`。

（2）付費移動 2 格後 `action_extra_delay == 40`，行動結束 `next_action_tick` 比只出一張 100 延遲牌多 40 刻。

（3）障礙格 (3,2) 與 (2,3)、(4,3) 封住時 `reachable_cells` 不含 (3,2) 後方格；敵人站 (3,3) 時路徑繞行（`find_path` 長度 ≥ 3）。

（4）`card_test_dash_strike`：對同列距離 3 的敵人出牌 → 主角停在相鄰格並造成 6 傷害；對非同行同列目標 `ValidatorInLine` 拒絕。

（5）`card_test_shove` 推距離 2：敵人在 (3,3) 推向北 → 到 (3,1)，`displaced_cells == 2`、無碰撞傷害；敵人在 (3,1) 推 → 不動、`collided == true`、受 `3 × 2 = 6` 碰撞傷害；(3,2) 後方 (3,1) 有另一敵人 → 推 0 格、兩者各受 3（`collision_damage_to_blocker` 設 3 的 fixture 變體）。

（6）2×2 敵人（既有案例）`ActionDisplaceUnit` 不動（`displace_max_footprint_area 1`），`is_immovable` 敵人同樣不動；`status_rooted` 的主角 `card_test_blink` 被 Validator 拒絕。

（7）`SWAP` 與 (3,3) 的 NEUTRAL 測試單位交換後兩者 anchor 互換、`unit_moved` 兩次；`PULL_ADJACENT` 把 (3,0) 的敵人拉到 (3,3)。

（8）`card_test_blink` 對被佔格拒絕、對距離 3 空格成功、距離 4 被 `card_range` 拒絕。

（9）`enemy_test_archer`（KEEP_RANGE 3）主角走到距離 2 後其 `planned_move_cell` 距離為 3，行動後實際位置一致且命中；`enemy_test_charger` 與主角同列距離 4、`move_range 3` → 行動後相鄰並命中；不同列時退化 APPROACH。

（10）`ThreatPreview` 數值在敵人預計移動後與實際受傷相等（既有案例延伸到 KEEP_RANGE／CHARGE）。

（11）`ActionSummonEnemies` 指定格被佔 → 生成在最近空格（距離 1，y 小者優先）。

（12）`ValidatorDistance >= 3` 的測試牌在距離 2 時 `card_is_playable` 為 false、glow 關閉；`ActionComputeBoardValue` 後 `card_values.distance` 等於 `BoardData.distance`。

（13）legacy 事件（無 encounter id）合成後主角仍可不移動直接出 `card_attack_basic`（免費移動 0 的框架預設路徑）。

**修訂（實作 Phase 2）**：第 2 條「多 40 刻」改為延遲 +40（速度 10 下 = 400 刻，下次行動 1400 vs 1000）；第 5 條撞牆案例改為敵人在邊緣 (3,0)、主角在 (3,1)（原寫法超出射程 1），「兩者各受 3」用距離 1 的變體卡；第 6 條定身時閃現在選牌階段即不可打（ValidatorPathExists 移動力檢查）；第 13 條由 CombatVictory（combat_flow.gd）斷言；「付費延遲相加」的斷言放 Board 第 2 條而非 ctb_flow；實際：suite `Board`（tests/board_flow.gd＋board_cases.gd＋board_fixture.gd，88 checks，標記 `BOARD PASS:`，All 中排在 Ctb 與 SaveLoad 之間），`--suite All` 全綠（Smoke 88、CombatVictory 89、CombatDefeat 48、Ctb 53、Board 88、其餘不變），pack 側寫 Smoke 66、合成測試 138；BoardView 觀感與滑鼠操作需使用者實機確認；實際驗收見 [phase-2 plan](../../plans/combat-framework/phase-2.md)。

實際逐條結果見 [phase-2 plan](../../plans/combat-framework/phase-2.md) 與 [phase-2-done-when.json](../../plans/combat-framework/phase-2-done-when.json)。
