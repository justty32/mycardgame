> 封存 2026-10-21，由 已完成（4c386e0）；現況見 wf/specs/dual-board/README.md 取代

# plan：戰鬥框架 Phase 3 波次（已完成 2026-10-19）

[spec](../../specs/combat-framework/README.md)｜[分階段](../../specs/combat-framework/08-phases.md)｜[Phase 2](phase-2.md)｜[INDEX](../../INDEX.md)

範圍：spec [Phase 3](../../specs/combat-framework/08e-phase-3-2b.md#phase-3波次)，加上 [14](../../specs/combat-framework/14-movement-intent-spawn.md) §7 的 WAIT_UNTIL_FREE／FAIL_SKIP（原列 2b，提前做）。不做 Phase 2b（場域格、控制區）與 Phase 4。程式 commit 為 `0d9da24`（重構）與 `4c386e0`（波次），本地補丁 `tools/patches/combat-framework-phase3.patch` 涵蓋兩者（`git diff c662729..4c386e0` 的 game/，已在 Phase 2 樹上 apply --check），登記在 [upstream.json](../../../tools/upstream.json)。

## 步驟一：拆 CombatDirector（行為不變）

639 行的 Director 拆成每場建立的元件，Director 保留委派，呼叫端不改：

- [BoardController](../../../game/scripts/combat/board/BoardController.gd)：建棋盤、部署主角、NEAREST_EMPTY 放置、移動預算與點格移動。
- [UnitSpawner](../../../game/scripts/combat/UnitSpawner.gd)：波次單位與棋盤召喚。
- [CombatActionPhases](../../../game/scripts/combat/CombatActionPhases.gd)：一次行動固定的開始／結束階段。
- [CombatStartActions](../../../game/scripts/combat/CombatStartActions.gd)：開戰前的初始動作。
- 意圖執行移到 `EnemyIntentController.perform_intent`。

重構後 `--suite All` 的 check 數與 Phase 2 完全相同。

## 步驟二：波次

[WaveController](../../../game/scripts/combat/WaveController.gd) 管波次：

- 第 0 波隨開戰開始。
- 清波條件：本波單位都已進場（或被跳過），且沒有存活的非雜兵敵人。成立時發 `wave_cleared(i)`、執行 `wave_on_cleared_actions`（parent＝主角），並把下一波排在「清空刻 + `wave_enter_delay_ticks`」。
- 到開始刻發 `wave_started(i)`、執行 `wave_on_start_actions`。
- 最後一波清空即勝利：在敵人死亡動畫結束時判定（舊時點），呼叫 `Combat.end_combat()`。`Combat.gd` 原本的「只剩雜兵」判定已刪除。

UnitSpawner 的待進場佇列：單位進場刻＝開始刻 + stagger×序號 + `spawn_delay_ticks`。Director 迴圈在彈出下一個單位前，先處理刻數不晚於它的進場項（同刻時進場先）；進場單位在該刻行動。進場格策略：

- NEAREST_EMPTY：整張滿時依 retry 欄位等待。
- WAIT_UNTIL_FREE：重試 `max_retries` 次後改用 NEAREST_EMPTY。
- FAIL_SKIP：直接跳過。

跳過的單位不擋清波。`Global.are_remaining_enemies()` 在戰鬥中委派給 `CombatDirector.has_remaining_opponents()`（存活敵人或尚有後續波次），所以 ActionHandler／HandManager 的 short-circuit 在波間不會觸發。TimelineBar 執行時加 `WaveLabel`（「Wave i/n」），只在多波遭遇顯示。

## 驗證（2026-10-19 Manjaro，godot-mono 4.7.2）

新 suite `Wave`（[wave_flow.gd](../../../tests/wave_flow.gd)＋[wave_cases.gd](../../../tests/wave_cases.gd)＋[wave_fixture.gd](../../../tests/wave_fixture.gd)，48 checks，在 All 中排在 Board 與 SaveLoad 之間）。spec 的 Done when 逐條有斷言：

- `wave_cleared(0)` 在刻 0 發出。
- 第 1 波在 300 進場；被佔格的單位等待後於 500 進 (1,0)。
- 波間打出的格擋牌仍生效。
- 第 2 波（1200）跳過被佔格單位；最後一波清空後才 `combat_ended`。
- 錢逐波 +10，共 +30。

另驗雜兵存活時仍清波，並留到下一波。CombatVictory 新增 1 條：舊單波遭遇依序 `wave_started(0)`、`wave_cleared(0)`、`combat_ended`。

`python3 tools/test_game.py --suite All` 全部 exit 0：

| Suite | checks |
|---|---|
| ResourceLifecycle | 127 |
| Dictionary | 47 |
| Smoke | 88 |
| CombatVictory | 90 |
| CombatDefeat | 48 |
| Ctb | 53 |
| Board | 88 |
| Wave | 48 |
| SaveLoad | write 28／read 56／rejected 73 |

除 CombatVictory 新增的 1 條外，既有 check 數與 Phase 2 相同。pack 側寫 Smoke 66 checks 通過。runner 合成測試 140 項（新增 2 項）、boundary lint 測試、new_pack 全過；boundary lint violations 0，strict 文件 lint 回傳 0。

## 與 spec 的偏差

已在 spec Phase 3 標「修訂（實作 Phase 3）」，共 (a)–(h)。重點：

- 清波只在擊殺後（等動作佇列清空）與每批進場後檢查。
- short-circuit 用 `has_remaining_opponents()`，不用 `is_combat_over()`，以保留雜兵存活時不短路的舊行為。
- 全雜兵的第 0 波仍在第一次擊殺後結束（舊行為）。
- 第 0 波開戰時就上棋盤；後續波在進場刻才生成。
- WAIT_UNTIL_FREE／FAIL_SKIP 提前實作（2b 列已註記）。
- 預計格淡色標記未做。
- Director 仍約 445 行。

## Phase 2b 前注意

- CombatDirector 約 445 行：迴圈、生命週期、玩家結束行動閘與委派。2b 的場域觸發宜另開元件（例如 FieldController），掛在 `combat_tick_advanced`／`unit_moved`／`unit_action_started` 上，不要再塞進 Director。
- 場域規則「波次生成預設不觸發 `on_enter`」：生成走 `UnitSpawner._enter_unit` 的 `board.place`，不發 `unit_moved`，2b 可沿用。
- 待進場項不會出現在 `project_timeline`；TimelineBar 看不到下一波。
- 跳過的單位只記在 `unit_spawner.skipped_units` 並印 log。

## 需使用者實機檢查（headless 無法驗）

Phase 1～3 的實機檢查合併在此（各 plan 末節保留原文）。Linux 開窗加 `--display-driver x11`，見 [dev-env](../../workflows/dev-env.md)。

1. 時間軸：TimelineBar 在頂端列的位置、重疊與字的可讀性；WaveLabel 的位置與可讀性。
2. 回合與 overlay：TurnOverlay 文字；開始／結束 overlay 動畫；End Turn 是否抽牌後才可按。
3. 棋盤：BoardView 位置、大小、是否和其他 UI 重疊，方塊與文字清楚度。
4. 高亮：免費格與付費格（斜紋，「+N」）好不好分；懸停路徑線；選牌後的形狀高亮；懸停敵人時的命中格、路徑與幽靈；打不到的意圖變淡。
5. 操作：滑鼠點格移動、點格或點敵人圖像選目標。
6. 進場：戰鬥中召喚與下一波進場的視覺順序（容器排版、棋盤方塊出現）、波間空檔觀感。
7. 決定：戰鬥者圖像要不要直接站在棋盤格上、跟著棋盤移動（目前不跟；agent 建議要）。

第 4、5 項要有移動與範圍卡，等中性示範內容包做好才看得到。已登記在 [WAIT_USER](../../WAIT_USER.md)。

## 後續決議

上方保留 Phase 3 當時驗收狀態；第 7 項已由使用者確認（[decisions.json](../../workflows/decisions.json) 第 20 列）：角色與敵人本體直接站在棋盤上、移動時跟隨，採雙方對峙的日式 RPG 回合戰鬥感。現行工程與未定美術細節見 [雙棋盤呈現分析](../../specs/dual-board/presentation.md)。本體站格已完成工程接線與 headless 回歸；最終 All 證據見現行分析，人工觀感仍未驗。第 1–6 項人工驗收仍未完成。
