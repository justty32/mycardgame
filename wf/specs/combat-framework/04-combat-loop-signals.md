# 戰鬥迴圈、每單位牌堆與訊號遷移

[README](README.md)

## 3.2 戰鬥迴圈：`CombatDirector` + 行動佇列取代 `Combat.gd` 回合流程

新節點 `CombatDirector`（`game/scripts/combat/CombatDirector.gd`，掛在 `RunScreen/Combat` 下；`Combat.gd` 只剩 HUD）。

```
combat_started(event_id)
  → 讀 EventData.event_encounter_object_id（或合成）→ 建 BoardData、Timeline
  → 生成出戰隊員單位（PartyUnit 場景，每人一個節點，綁 PartyMemberData）到部署格；AI 隊員自動擺位，玩家可在「部署階段」拖動主角（**已決，使用者 2026-10-19**：第一版先用遭遇資料的預設格 `encounter_deploy_cells`，不做部署 UI）
  → 生成第 0 波敵人；每單位 next_action_tick = 0 + spawn_delay；敵人決定首個意圖（intent_initial）
  → 首次行動前處理：location/event initial actions、藥物 initial、卡牌 initial（沿 Combat.gd:365-425 搬過來，parent 改主角單位）
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
    if unit is Enemy: unit.decide_next_intent()        # 進入等待時決定並顯示意圖（取代 Enemy.gd:243）
    timeline.push(unit)
    _check_wave()                                      # 本波全滅 → wave_cleared → 下一波生成（登場延遲 + 錯開）→ wave_started
  end_combat()

is_combat_over(): 主角倒下且 hero_down_ends_run，或出戰隊員全倒下 → 敗；最後一波清空且無存活敵人 → 勝
```

要點：
迴圈要點已抽到 [loop-notes.json](loop-notes.json)（6 列，依原順序）。欄位：no（序號）、text（條文原文）。

## 3.3 `HandManager` 的每單位牌堆

```
class UnitPiles（RefCounted）: hand, draw, discard, exhaust: Array[CardData]; custom_piles; cards_retained_this_action; cards_with_modified_action_energy
HandManager
  unit_piles: Dictionary[String, UnitPiles]      # key = unit_uid
  active_unit_uid: String
  func set_active_unit(unit) / get_piles(unit_uid) / get_active_piles()
  func generate_combat_deck(member: PartyMemberData)   # 從 member_deck 複製（取代 HandManager.gd:109-115）
  var player_hand: Array[CardData]: get = _get_active_hand, set = _set_active_hand   # 相容 proxy（player_draw/discard/exhaust 同）
```
- 既有 14 個外部讀取者透過 proxy 不改即可編譯；但凡「指定單位」的新邏輯一律用 `get_piles(uid)`。`STANDARD_PILE_NAME_TO_PILE_PROPERTY_NAME`（`HandManager.gd:65-71`）的 `get/set` 路徑經 proxy 落到 active piles。
- `Hand`（UI）綁 `active_unit`：`Hand.gd:13` 的 `player` 改為 `HandManager.get_active_unit()`；`create_cards_in_hand` 在切換單位時整組重建。
- 能量：`Global.player_data.player_energy` 改為 proxy 到**行動中單位**的 `member_energy`（`CardData.gd:199-201`、`Card.gd:160`、`HandManager.gd:318-350` 不必改）；敵人沒有能量，AI 隊員有。
- `perform_end_of_turn_hand_actions`（`HandManager.gd:460-535`）改名 `perform_end_of_action_hand_actions(unit_uid)`，由 `CombatDirector._end_action` 依 `rules.discard_hand_on_action_end` 呼叫。
- `card_energy_cost_until_turn`（`CardData.gd:17`）語意改「直到持有者下次行動結束」，欄位名保留（JSON 相容）。

## 3.4 訊號重新定義與監聽者遷移

新增（`Signals.gd`）：

（表）已抽到 [signals.json](signals.json)（11 列）。欄位：訊號、參數、時點。

舊訊號處置：`player_turn_started/ended` **保留**，語意改為「主角（player_party[0]）的行動開始／結束」；`enemy_turn_started/ended` 保留，語意改為「某一個敵人的行動開始／結束」（參數維持無；不建議新碼使用）。`end_turn_requested` 改名。`ActionEndTurn` 檔名保留、內部改發新訊號。

監聽者遷移表：

（表）已抽到 [listener-migration.json](listener-migration.json)（16 列）。欄位：監聽者、現況、遷移。
