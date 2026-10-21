# 戰鬥迴圈、每單位牌堆與訊號遷移

[README](README.md)

## 3.2 戰鬥迴圈：`CombatDirector` + 行動佇列取代 `Combat.gd` 回合流程

新節點 `CombatDirector`（`game/scripts/combat/CombatDirector.gd`，掛在 `RunScreen/Combat` 下；`Combat.gd` 只剩 HUD）。

```
combat_started(event_id)
  → 讀 EventData.event_encounter_object_id（或合成）→ 建 BoardData、Timeline
  → 生成出戰隊員單位（PartyUnit 場景，每人一個節點，綁 PartyMemberData）到部署格；AI 隊員自動擺位，玩家可在「部署階段」拖動主角（**已決**：第一版先用遭遇資料的預設格 `encounter_deploy_cells`，不做部署 UI；decisions.json 第 16 列）
  → 生成第 0 波敵人；每單位 next_action_tick = 0 + spawn_delay；敵人決定首個意圖（intent_initial）
  → 首次行動前處理：location/event initial actions、藥物 initial、卡牌 initial（自舊 `Combat.gd` 首回合流程搬出，parent 改主角單位；現為 `CombatStartActions.perform`）
  → _run_loop()

_run_loop()（單一 async 迴圈，取代 AnimationPlayer 串接）
  while not is_combat_over():
    unit = timeline.pop_next()                         # 最小 next_action_tick；平手依 rules.tie_break
    advance_clock(unit.next_action_tick)               # emit combat_tick_advanced(prev, now)；處理「每 N 刻」狀態
    await _begin_action(unit)                          # 格擋重置（依 rules）、能量、抽牌、狀態 PRE/POST_DRAW、emit unit_action_started
    plan = await unit.controller.decide(ctx)           # PlayerInput：等 UI 的 end_action_requested；AI：同步算出 AiPlan 後逐步執行
    await _execute_plan(plan)                          # 移動→出牌（走 HandManager 佇列）→等待；每步後 _check_downed()
    await _end_action(unit)                            # 狀態 PRE/POST_DISCARD、棄牌（依 rules）、計算 delay、emit unit_action_ended
    unit.next_action_tick = now + wait(delay, unit.speed)
    if unit is Enemy: unit.decide_next_intent()        # 進入等待時決定並顯示意圖（現 `Enemy.decide_next_intent`）
    timeline.push(unit)
    _check_wave()                                      # 本波全滅 → wave_cleared → 下一波生成（登場延遲 + 錯開）→ wave_started
  end_combat()

is_combat_over(): 主角倒下且 hero_down_ends_run，或出戰隊員全倒下 → 敗；最後一波清空且無存活敵人 → 勝
```

### 迴圈要點

**（1）**`Global.are_remaining_enemies()` 改為委派 `CombatDirector.has_living_opponents()`，`ActionHandler._perform_actions` 的 short-circuit 改問 `CombatDirector.is_combat_over()`，否則波間空檔會把所有攻擊短路。**修訂（Phase 1）**：委派延到 Phase 3 波次一起做；`Global.are_remaining_enemies()` 與 short-circuit 暫不變，`CombatDirector` 已提供 `has_living_opponents()`／`is_combat_over()`。**修訂（Phase 3）**：已委派：`Global.are_remaining_enemies()` 在戰鬥中回傳 `CombatDirector.has_remaining_opponents()`（存活敵人或尚有後續波次／待進場單位），`ActionHandler`／`HandManager` 呼叫點不變；short-circuit 不直接問 `is_combat_over()`，以保留雜兵存活時不短路的舊行為。

**（2）**敵人行動 = 執行其意圖：先依 `enemy_intent_move` 用 `ActionMoveUnit` 移動，再用 `BoardData.cells_in_shape` 解析目標；射程不足則改為「等待」並保留意圖（AI 相同邏輯）。沿用舊 `Combat.gd` 敵方回合的動作組裝（現由 `Enemy.build_intent_actions_data` 產生、`EnemyIntentController.perform_intent` 執行），只把 `[player]` 換成解析結果。

**（3）**玩家單位行動時：`HandManager.set_active_unit(unit)`、`Hand` 顯示其手牌、`EndActionButton` 啟用；`CombatEndTurn` 改名 `CombatEndAction` 行為不變（`end_turn_requested` → `end_action_requested`）。**修訂（Phase 1）**：已改名 `CombatEndAction`、按鈕發 `end_action_requested`（`end_turn_requested` 留作別名）；`set_active_unit` 與 UnitPiles 留 Phase 4。

**（4）**AI 單位行動時：手牌不顯示（或淡出），`CombatDirector` 直接把 `CardPlayRequest` 丟進 `HandManager.add_card_to_play_queue`（`require_energy=true`，走同一條驗證與攔截鏈），所以 AI 不能作弊。

**（5）**「每回合一次」的卡牌／狀態語意：以**該單位的 action_count** 計；「持續 X 刻」以 `combat_tick_advanced` 計。`StatusEffectData.status_effect_action_process_times` 新增尾端枚舉 `UNIT_ACTION_START`、`UNIT_ACTION_END`、`EVERY_N_TICKS`（N 存 `status_effect_tick_interval`），舊值重釋：`PRE/POST_DRAW_PLAYER_START_TURN` = 我方單位行動開始抽牌前後；`PRE/POST_DISCARD_PLAYER_END_TURN` = 我方單位行動結束棄牌前後；`PRE/POST_ENEMY_TURN` 與 `PRE/POST_ENEMY_INTENT` 合併為該敵人行動開始／結束（兩對都觸發，保持舊資料有效）。**修訂（Phase 1 實作）**：三個尾端枚舉與 `status_effect_tick_interval`（預設 100）已加；舊值依上述重釋，敵人行動開始依序觸發 PRE_ENEMY_TURN → PRE_ENEMY_INTENT，結束依序 POST_ENEMY_INTENT → POST_ENEMY_TURN；`EVERY_N_TICKS` 由 `BaseCombatant.perform_tick_status_effects(prev, now)` 在時鐘前進時處理。

**（6）**倒下：我方單位 HP 0 → `unit_downed`、移出時間軸與棋盤（格可通過）、手牌棄掉；`downed_member_policy` 決定戰後處置。`Player._on_player_health_changed` → `play_death_animation` 的死亡流程只對主角保留「敗北」分支。**已決**（decisions.json 第 13 列）：隊員倒下＝本場退場、戰後以 1 HP 回歸（`downed_member_policy` 框架預設 `REVIVE_AFTER_COMBAT_1HP`）；主角倒下＝敗北（`hero_down_ends_run=true`）。`LEAVE_PARTY`／`PERMADEATH` 僅是題材包可 patch 的選項，框架預設不用。

## 3.3 `HandManager` 的每單位牌堆

見 [04b-unit-piles.md](04b-unit-piles.md)。

## 3.4 訊號重新定義與監聽者遷移

新增（`Signals.gd`）（修訂：Phase 0 已宣告；`member`／`plan` 參數在 PartyMemberData／AiPlan 出現前不標型別）：

（表）已抽到 [signals.json](signals.json)（11 列）。欄位：訊號、參數、時點。

舊訊號處置：`player_turn_started/ended` **保留**，語意改為「主角（player_party[0]）的行動開始／結束」；`enemy_turn_started/ended` 保留，語意改為「某一個敵人的行動開始／結束」（參數維持無；不建議新碼使用）。`end_turn_requested` 改名。`ActionEndTurn` 檔名保留、內部改發新訊號。

修訂（Phase 1）：`end_turn_requested` 未刪，保留為 `end_action_requested` 的舊別名（Director 兩者都聽）。`player_turn_started` 在主角行動開始、補能量與抽牌前發，`player_turn_ended` 在棄牌後；`turn_count` 由 Director 在動畫前呼叫 `StatsHandler.begin_hero_action()` 遞增。遺物與 CardDecorator 仍連 `player_turn_*`（時點同舊版），改連 `unit_action_*` 延到 Phase 4。各列實際處置見下表的「修訂」。

監聽者遷移表：

（表）已抽到 [listener-migration.json](listener-migration.json)（16 列）。欄位：監聽者、現況、遷移。
