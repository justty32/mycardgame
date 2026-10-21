# plan：戰鬥框架 Phase 1 CTB + 單一主角（已完成 2026-10-19）

[spec](../../specs/combat-framework/README.md)｜[分階段](../../specs/combat-framework/08-phases.md)｜[Phase 0](phase-0.md)｜[INDEX](../../INDEX.md)

範圍：spec [Phase 1](../../specs/combat-framework/08b-phase-1.md)。一名主角對多個敵人，依速度在時間軸上排隊；速度相同且用預設規則時，順序等於舊的回合交替（hero@0、enemy@0、hero@1000、enemy@1000…）。程式 commit 為 `ef33568`，本地補丁為 `tools/patches/combat-framework-phase1.patch`（登記在 [upstream.json](../../../tools/upstream.json)）。

## 步驟

新增 [CombatDirector.gd](../../../game/scripts/combat/CombatDirector.gd)，掛在 Root.tscn 的 `RunScreen/Combat` 下，屬 `combat_director` 群組，用 `Global.get_combat_director()` 取得。它跑單一 async 行動迴圈，並提供 `has_living_opponents()` 與 `is_combat_over()`。`combat_ended`、`run_ended`、`player_killed`、`tree_exiting` 都會停止迴圈，做法沿用 ActionHandler 的世代計數。

[CombatTimeline.gd](../../../game/scripts/combat/CombatTimeline.gd) 是 RefCounted 優先佇列，`next_action_tick` 最小的先行動。平手依 `tie_break`：預設速度高者先，再來我方先於敵方，最後看生成順序。等待刻數 `wait_for(delay, speed)` = delay × timeline_delay_scale ÷ speed，至少 1。`project(count)` 給 UI 用。

`controllers/` 有 BaseUnitController、PlayerInputController 與 EnemyIntentController。PlayerInputController 等 `end_action_requested`，由 [CombatEndAction.gd](../../../game/scripts/ui/CombatEndAction.gd) 處理後呼叫 `finish_player_action`。CombatEndAction 取代已刪除的 CombatEndTurn.gd，枚舉值相同。EnemyIntentController 由 `perform_enemy_intent` 執行，動作用 `Enemy.build_intent_actions_data` 組出。

[TimelineBar](../../../game/scripts/ui/TimelineBar.gd) 是頂端的 HBoxContainer，位於 x 240–1000、y 12–52。它顯示「Tick N」和接下來 8 個預測行動（`name@tick`），行動中的單位加方括號。只在 Director 執行中可見。

Combat.gd 只剩 HUD：解析事件、經 EnemyContainer 生成敵人，然後呼叫 `begin_combat()`。`end_combat()` 每場只跑一次。End Turn 按鈕發 `end_action_requested`，在 `unit_action_started(hero)` 時啟用。Root.tscn 的 start_turn 只保留 TurnOverlay 軌與 `update_turn_label`，end_turn 只保留 disabled 軌。Director 播放這兩段動畫並等它們結束。TurnOverlay 顯示「Tick T - Action N」。

資料新增欄位：`enemy_speed` 與 `character_speed` 預設 10。`card_action_delay` 為 -1 時用 `rules.default_action_delay`，一次行動的 delay 取該次所出各牌的最大值。另有 `enemy_intent_action_delay`。StatusEffectData 尾端加 UNIT_ACTION_START、UNIT_ACTION_END、EVERY_N_TICKS，`status_effect_tick_interval` 預設 100，舊時點的重釋見 [§3.2 迴圈要點](../../specs/combat-framework/04-combat-loop-signals.md#迴圈要點)（5）。

HandManager 新增 `get_hand_limit()`，讀 `rules.hand_limit`。`perform_end_of_action_hand_actions()` 保留舊名當別名。`reset_block_on_action_start` 同時用在主角和敵人的意圖 payload。

StatsHandler 的 `begin_hero_action()` 遞增 `turn_count` 並重置每回合統計。`is_player_turn` 只在 `player_turn_started` 到 `player_turn_ended` 之間成立。另加 `combat_tick` 與 `unit_action_counts`。

訊號語意：`player_turn_*` 代表主角一次行動，`enemy_turn_*` 代表一個敵人的一次行動。`end_turn_requested` 保留為舊別名。`unit_action_started` 與 `unit_action_ended` 對所有單位都發。`combat_tick_advanced` 只在時鐘真的前進時發。UnitRegistry 發 `unit_spawned` 與 `unit_removed`。召喚的單位以「剛行動完」的狀態入列，並在生成時決定意圖。

主角一次行動的順序：

1. `begin_hero_action`
2. start_turn 動畫（1 秒）
3. `player_turn_started`
4. 補能量
5. `update_incoming_damage`
6. 依規則重置格擋
7. PRE_DRAW 狀態
8. 抽牌（`draw_per_action`）
9. POST_DRAW 與 UNIT_ACTION_START 狀態
10. `unit_action_started`
11. 解鎖手牌，等待玩家結束行動
12. end_turn 動畫（0.5 秒）
13. `player_turn_ended`
14. PRE_DISCARD 狀態
15. 依規則棄牌
16. POST_DISCARD 與 UNIT_ACTION_END 狀態
17. `unit_action_ended`
18. 計算 delay 與等待刻數，重新入列

敵人的行動依序為 PRE_ENEMY_TURN、PRE_ENEMY_INTENT、UNIT_ACTION_START、`unit_action_started`、執行意圖、POST_ENEMY_INTENT、POST_ENEMY_TURN、UNIT_ACTION_END、`unit_action_ended`，然後呼叫 `decide_next_intent()`。第一場戰鬥的地點／事件／藥水／卡牌初始動作在迴圈開始前跑一次。主角死亡會中止迴圈，致命的那次敵人行動不會發 ended。

## 驗證（2026-10-19 Manjaro，godot-mono 4.7.2）

新 suite `Ctb`（[ctb_flow.gd](../../../tests/ctb_flow.gd)＋[ctb_fixture.gd](../../../tests/ctb_fixture.gd)，53 checks，標記 `CTB PASS:`）排在 All 的 CombatDefeat 與 SaveLoad 之間，ps1 ValidateSet 已加入。fixture：seed 20261019；主角速度 10；敵人 fast 速度 20、意圖格擋 1，slow 速度 5、意圖 1×1 攻擊；牌組 5 張原生 Basic Block。

Ctb 斷言：前 8 筆行動為 fast@0、hero@0、slow@0、fast@500、fast@1000、hero@1000、fast@1500、fast@2000，時鐘 0→500→1000→1500→2000；500 刻 EVERY_N_TICKS 狀態 10→8（刻 1000）→6（刻 2000）；格擋 10→9→主角第二次行動開始歸 0；`turn_count` 2 = 主角行動數（fast 3 次，之後 5 次）；`is_player_turn` 只在主角行動中；TimelineBar 有內容、TurnOverlay「Tick 1000 - Action 2」；中途釋放場景後無殘留 Director。

[combat_flow.gd](../../../tests/combat_flow.gd)：勝利路徑敵人 started／ended 各 1 次、結束時刻 1000；敗北路徑致命行動只 started 不 ended、Director 已停。抽 5、能量 3、14 傷害消 10 格擋加 4 HP、`turn_count == 2` 不變。

`python3 tools/test_game.py --suite All` 全部 exit 0、0 failures：

| Suite | checks |
|---|---|
| ResourceLifecycle | 127 |
| Dictionary | 47 |
| Smoke | 82 |
| CombatVictory | 87 |
| CombatDefeat | 46 |
| Ctb | 53 |
| SaveLoad | write 28／read 56／rejected 73 |

pack 側寫 Smoke 通過（60 checks）；證據在本機 artifacts/verification/20261019-214534-ff8942d8（未提交）。runner 合成測試 136 項（新增 2 項）、boundary lint 測試 19 項、new_pack 測試 14 項全過；boundary lint violations 0，strict 文件 lint 回傳 0。

## 與 spec 的偏差（已在 spec Phase 1 等處標「修訂」）

- (a) 遺物三檔與 CardDecoratorDynamicValueModifier 仍連 `player_turn_*`（時點同舊版）；`artifact_trigger_scope` 延到 Phase 4。
- (b) `turn_count` 由 Director 在動畫前呼叫 `begin_hero_action()` 遞增，不靠 `unit_action_started`。
- (c) `controller` 在 Phase 1 就是 BaseUnitController 型別（原訂 Phase 4）。
- (d) `are_remaining_enemies()` 與各 short-circuit 不改；委派 Director 留到 Phase 3。
- (e) Combat.gd 仍負責生成敵人再交給 Director；生成搬進 Director 留到 Phase 2。
- (f) `enemy_intent_action_delay` 提前加入。
- (g) 戰鬥結束仍由 Combat.gd 依死亡動畫判定；Director 只負責停止迴圈。
- (h) 召喚的敵人在生成時決定意圖，RNG 時點只對召喚不同。
- (i) ValidatorEnemyAttacking 與 `update_incoming_damage` 留到 Phase 2。

## 未做／交給 Phase 2+

- 棋盤、移動、形狀、波次、UnitPiles、`unit_downed`、隊伍。
- `CombatEndTurn` 類名已刪除。mod 須改用 `CombatEndAction.END_ACTION_QUEUE_IMMEDIACY`；框架內只有 GlobalTestDataGenerator 引用過它。

## 需使用者實機檢查（headless 無法驗）

TimelineBar 在頂端列的位置與重疊、文字可讀性；TurnOverlay 的文字；End Turn 是否在抽牌後才啟用；開始／結束 overlay 動畫的觀感；戰鬥中召喚時的視覺順序。已登記在 [WAIT_USER](../../WAIT_USER.md)。
