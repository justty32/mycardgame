# 敵人意圖表達與 AI 隊員決策

[README](README.md)

## 3.5 敵人意圖在棋盤上的表達

意圖表達規則已抽到 [intent-display-rules.json](intent-display-rules.json)（4 列，依原順序）。欄位：no（序號）、text（條文原文）。

## 3.6 AI 隊員的出牌與移動決策（可插拔，先做貪婪評分）

```
BaseUnitController（RefCounted）
  func decide(ctx: AiContext) -> AiPlan            # 可 await（玩家輸入）
PlayerInputController   # 等 end_action_requested；期間 UI 直接把 CardPlayRequest 丟進 HandManager（現行路徑）
GreedyAiController      # 一步貪婪，見下
（預留）SearchAiController

AiContext: unit, board, timeline(投影 N 格), piles, rules, profile(AiProfileData), threat(ThreatPreview), commands(戰術指令；已決，使用者 2026-10-19：第一版不做，恆為空，Phase 5 之後再加)
AiPlan: steps: Array[AiStep]  # {type: MOVE, cell} | {type: PLAY, card, cell, targets} | {type: WAIT}
```

貪婪演算法（每步 O(可達格 × 手牌 × 合法目標格)，5×5／手牌 ≤10 可接受）：
貪婪演算法四步已抽到 [greedy-steps.json](greedy-steps.json)（4 列，依原順序）。欄位：no（序號）、text（條文原文）。

選牌獎／購卡（局外，§3.7）共用 `AiDraftScorer`：`score(card) = ai_draft_weights[role] + 稀有度加成 − duplicate_penalty × 牌組同名數 + 費用曲線修正`。
