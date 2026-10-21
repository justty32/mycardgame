# 敵人意圖表達與 AI 隊員決策

[README](README.md)

## 3.5 敵人意圖在棋盤上的表達

**（1）**決定時點：敵人**行動結束、進入等待**時依 `enemy_intent_next_intent_weights` 抽下一個意圖，並依 `enemy_intent_target_rule` 預選目標單位（記 `intended_target_uid`）；每次 `unit_moved`／`unit_downed`／`timeline_changed` 後由 `ThreatPreview.refresh()` 重新解析（目標可能已移出射程 → 顯示「無法命中」灰色圖示；實際行動時再以 `enemy_intent_move` 補位）。

**（2）**顯示三處：敵人頭上意圖圖示（沿用 `Enemy` 的 `enemy_intent` 圖示節點）+ 數值（沿用 `Enemy.update_enemy_intent` 的攔截預覽，目標改 `intended_target`）；時間軸條目上的小圖示；滑鼠懸停敵人或其時間軸條目時，`BoardView` 高亮 `cells_in_shape(enemy.anchor, intended_target.anchor, shape, pierce)`。

**（3）**我方每個單位頭上顯示「下一次自己行動前預計受傷」：`ThreatPreview` 把所有 `next_action_tick < unit.next_action_tick` 的敵人意圖累加到其命中的單位（取代 `Player.update_incoming_damage_amount` 的舊算法）。

**（4）**所有解析皆為純函式（`BoardData` + 意圖資料 → 格與單位），同一函式供 AI 評分使用，避免 UI 與 AI 看到不同事實。

## 3.6 AI 隊員的出牌與移動決策（可插拔，先做貪婪評分）

```
BaseUnitController（RefCounted）
  func decide(ctx: AiContext) -> AiPlan            # 可 await（玩家輸入）
PlayerInputController   # 等 end_action_requested；期間 UI 直接把 CardPlayRequest 丟進 HandManager（現行路徑）
GreedyAiController      # 一步貪婪，見下
（預留）SearchAiController

AiContext: unit, board, timeline(投影 N 格), piles, rules, profile(AiProfileData), threat(ThreatPreview), commands(戰術指令；已決：第一版不做，恆為空，Phase 5 之後再加，見 decisions.json 第 15 列)
AiPlan: steps: Array[AiStep]  # {type: MOVE, cell} | {type: PLAY, card, cell, targets} | {type: WAIT}
```

貪婪演算法（每步 O(可達格 × 手牌 × 合法目標格)，5×5／手牌 ≤10 可接受）分四步：

**（1）**位置分：對每個可達格 c（含原地），`pos_score(c) = Σ profile.ai_position_weights[k] * feature_k(c)`，特徵：與主角距離、是否在主角與最近敵人之間、受威脅值（ThreatPreview 在該格的預計傷害）、可打到的敵人數。移動到最高分格（若與原地差 < ε 不動；移動成本依 rules.extra_move_delay_per_cell 折算成負分）。

**（2）**出牌迴圈：對手牌每張可付費卡 × 每個合法目標（`cells_in_shape` 解析），用 `card_ai_hints.role` 查 `profile.ai_weights[role]`，數值用 **preview 攔截**（`BaseAction._intercept_action(targets, preview_mode=true)` 取 `get_shadowed_action_values(value_key)`）得到實際傷害／格擋／治療，乘以目標偏好（`ai_target_bias`：低 HP、主角標記、最近）與陣營修正（治療友軍 HP 比例低於閾值才計分）。扣 `danger`（卡牌自帶代價提示）× `ai_weights.risk`。取最高分；若最高分 ≤ 0 或能量不足則停。重複直到無牌可打。

**（3）**若整個行動沒有出牌且 `ai_weights.save_energy > 0` → `WAIT`（短延遲）。

**（4）**決定性：所有打破平手的隨機用 `get_player_rng("rng_ai")`；plan 以 `ai_plan_decided` 發出，測試可斷言。

選牌獎／購卡（局外，§3.7）共用 `AiDraftScorer`：`score(card) = ai_draft_weights[role] + 稀有度加成 − duplicate_penalty × 牌組同名數 + 費用曲線修正`。
