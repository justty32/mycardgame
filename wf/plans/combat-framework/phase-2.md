# plan：戰鬥框架 Phase 2 棋盤 + 移動 + 範圍／形狀卡（已完成 2026-10-19）

[spec](../../specs/combat-framework/README.md)｜[分階段](../../specs/combat-framework/08-phases.md)｜[Phase 1](phase-1.md)｜[INDEX](../../INDEX.md)

範圍：spec phases.json 第 2 列，含移動增補（[11](../../specs/combat-framework/11-movement-active.md)–[16](../../specs/combat-framework/16-movement-phasing.md) 的「Phase 2」欄）。不做 Phase 2b（場域格、控制區）與 Phase 3（波次流程）。程式 commit 為 `0196e91`，本地補丁為 `tools/patches/combat-framework-phase2.patch`（登記在 [upstream.json](../../../tools/upstream.json)）。

## 預設與相容

框架預設不變：`combat_rules_default` 沒有免費／付費移動，卡牌 `card_range = -1` 不檢查距離，意圖 `enemy_intent_range = -1`、`HOLD`、目標 `HERO`。沒有 `event_encounter_object_id` 的事件由 `EncounterData.synthesize_from_event` 合成一波遭遇：預設 5×5，敵人依序排在北側一列置中，主角在南側一列中央。因此既有事件、卡牌與 example_mod 的數值契約不變（CombatVictory 的舊斷言照舊）。

## 步驟

棋盤核心在 `game/scripts/combat/board/`（BoardData、BoardTargeting、IntentResolver、ThreatPreview，檔案職責見 [code-map/combat-framework](../../workflows/common/code-map/combat-framework.md)）。尋路是四向 BFS，展開順序 N、E、S、W，結果決定性；障礙格不可進入，飛行單位（`ignores_occupancy`）可越過但不能停。遭遇資料 EncounterData／EncounterWaveData 的 SCHEMA 是 `encounters/`，格子清單寫成 `[[x, y], ...]`。

[CombatDirector](../../../game/scripts/combat/CombatDirector.gd) 現在負責開戰：讀遭遇（或合成）、建棋盤、把主角放上部署格，再經 EnemyContainer 生成第 0 波並放到指定格（被佔就找最近空格）。原本在 Combat.gd 的生成已搬過來，`begin_combat(event)` 改帶事件參數。其他職責：

- 我方行動開始時把移動點重設為 `free_move_per_action`。
- `request_player_move` 處理點格移動：先用免費點數，再用付費格；每付費一格，`action_extra_delay` 加 `extra_move_delay_per_cell`。
- `_compute_action_delay` 把付費延遲加在「本次打出各牌延遲的最大值」上，不參與取 max。
- `move_split_allowed = false` 時，打出第一張牌就結束本次移動。
- 敵人行動時先依意圖移動，再對命中的單位執行意圖；打不到時跳過攻擊，並保留這個意圖到下次行動。
- 單位移動、生成、死亡或時間軸變動後重算 ThreatPreview。

棋盤 Action 放在 `game/scripts/actions/board_actions/`：ActionMoveUnit（TO_CELL／TOWARD／AWAY／TELEPORT）、ActionDisplaceUnit（PUSH／PULL／PULL_ADJACENT／SWAP／TO_CELL，撞牆或撞單位會停住，並依碰撞造成傷害）、ActionGrantMovePoints、ActionComputeBoardValue。Validator 放在 `game/scripts/validators/board/`：Distance、CellsMoved、InLine、PathExists、CellFree。InterceptorRooted（測試資料 `status_rooted`）把移動與位移的 distance 設為 0。都登記在 Scripts 常數。

資料欄位：卡牌、意圖、敵人、角色、規則尾端與 BaseCombatant 依 phases.json 第 2 列加入，預設值都保留舊行為；CardPlayRequest 加 `acting_unit`、`selected_cell`、`resolved_targets`；TARGET_OVERRIDES 尾端加 7 個值。

輸入流程：[Hand](../../../game/scripts/ui/Hand.gd) 以 `cell_clicked` 選目標。檢查順序是射程、陣營、空格，最後在選定格之後重跑一次棋盤 Validator；被拒時 `last_target_rejection` 記錄原因，牌保持選取。沒有選牌時，點格就是移動。點敵人圖像（`enemy_clicked`）會轉成點它所在的格。`HandManager._play_card` 有 `resolved_targets` 時用它當目標，出牌者改為 acting_unit，`card_move_distance` 會加一個先執行的移動。

[BoardView](../../../game/scripts/ui/BoardView.gd) 是自繪的 Control，由 Combat 在執行時建立，位在左上 (16,120)，只在 Director 執行中顯示。畫面內容：

- 格子、部署區與障礙。
- 單位方塊與名稱縮寫，行動中的單位有外框。
- 可移動的格：免費格填色；付費格畫斜紋，並標出「+N」額外刻數。
- 懸停可達格時畫出路徑。選了牌時，顯示該牌的形狀範圍。
- 懸停敵人時，畫出它的命中格、預計路徑，以及停在 planned_move_cell 的半透明幽靈。

意圖打不到時，敵人頭上的意圖圖示會變淡。Player 的預計受傷與 ValidatorEnemyAttacking 都改看 ThreatPreview。

測試資料（GlobalTestDataGenerator）：`status_rooted`、`interceptor_rooted`、`card_test_dash_strike`、`card_test_shove`、`card_test_blink`、`enemy_test_charger`（CHARGE）、`enemy_test_archer`（KEEP_RANGE 3）。這些都不進卡包也不進事件，`combat_rules_default` 不改。

## 驗證（2026-10-19 Manjaro，godot-mono 4.7.2）

新 suite `Board`：[board_flow.gd](../../../tests/board_flow.gd) 負責回報，情境在 [board_cases.gd](../../../tests/board_cases.gd)，fixture 是 [board_fixture.gd](../../../tests/board_fixture.gd)。共 88 checks，標記 `BOARD PASS:`，在 All 中排在 Ctb 與 SaveLoad 之間；runner、ps1 ValidateSet 與合成測試都已加入。fixture 在記憶體裡把規則改成免費 1 格、付費 2 格、每格 +20；棋盤 7×5，主角在 (3,4)。

phases.json 的 13 條 Done when 全部有斷言：

phases.json 的 13 條 Done when 全部有斷言，逐條結果記在 [phase-2-done-when.json](phase-2-done-when.json)（13 列，欄位：no、結果）。

基本項另驗距離、射程拒絕、CROSS 命中 3 個單位、LINE／LINE_PIERCE，以及點 2×2 單位的任一格都能選中它。Smoke 的 probe 驗合成遭遇、各形狀的格數、曼哈頓距離與 EncounterData 的 JSON patch。

`python3 tools/test_game.py --suite All` 全部 exit 0、0 failures：

| Suite | checks |
|---|---|
| ResourceLifecycle | 127 |
| Dictionary | 47 |
| Smoke | 88 |
| CombatVictory | 89 |
| CombatDefeat | 48 |
| Ctb | 53 |
| Board | 88 |
| SaveLoad | write 28／read 56／rejected 73 |

pack 側寫的 Smoke（題材內容包加其 tests）通過，共 66 checks。runner 合成測試 138 項、boundary lint 測試 19 項、new_pack 14 項全過；boundary lint 的 violations 為 0，strict 文件 lint 回傳 0。

## 與 spec 的偏差（已在 phases.json 第 2 列標「修訂 2026-10-19（實作 Phase 2）」）

偏差 (a)–(n) 記在 [phase-2-deviations.json](phase-2-deviations.json)（14 列，欄位：id、說明）。重點：BoardView 是執行時建立的自繪 Control、戰鬥者圖像不跟棋盤移動；EnemyContainer 未改名；尋路只做四向 BFS；FLANK／TELEPORT 等留到 2b 並有退回規則；ThreatPreview 每個敵人只計一次當前意圖；Done when 第 2、5、6、13 條的數值或落點有調整。

## Phase 3 前注意

- `_setup_board` 只生成第 0 波（會讀 spawn_delay_ticks）。`_check_wave` 可以直接重用 `place_unit_nearest`（NEAREST_EMPTY），但 WAIT_UNTIL_FREE 與 FAIL_SKIP 還沒實作。
- 戰鬥結束仍由 Combat.gd 依死亡動畫判定；`are_remaining_enemies` 與 HandManager／ActionHandler 的 short-circuit 也都還沒委派 Director。
- 生成的單位延遲一幀才入列；同一幀內查 timeline 會看不到它。
- CombatDirector 已有 639 行，超過程式檔 300 行的檢視門檻。Phase 3 加波次時，建議把棋盤與生成抽成子物件。

## 需使用者實機檢查（headless 無法驗）

- BoardView 的位置、大小與是否和其他 UI 重疊，方塊與文字是否清楚。
- 免費格與付費格（斜紋，「+N」刻）的高亮是否好辨認；懸停時的路徑線。
- 選牌後懸停格子時的形狀高亮；懸停敵人時的命中格、路徑與幽靈。
- 意圖打不到時圖示變淡的效果。
- 實際用滑鼠點格移動與選目標，以及點敵人圖像選目標。
- 戰鬥者圖像不跟著棋盤移動，需要使用者決定是否改成圖像跟隨棋盤。

以上已登記在 [WAIT_USER](../../WAIT_USER.md)。
