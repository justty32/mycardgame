# 移動規則一：主動移動（原移動草案 §1）

[README](README.md)

狀態：草案，已併入本 spec。本檔起 11–15 為「移動規則增補」，題材中立；內容原意不改，只做編排。分檔：11 主動移動、12 強制位移與控制區、13 場域格與位置條件、14 敵人移動意圖與波次進場、15 卡牌關鍵字與積木；原 §9 分階段分配已併入 [08-phases.md](08-phases.md#移動增補的階段分配原移動草案-9)。原草案的合併落點為 03、05、08、10（Phase 2 欄併入 [Phase 2](08c-phase-2.md)、之後欄成為 Phase 2b）。

前提：沿用 spec 既有定義——共用棋盤 `BoardData`、`footprint`／佔格、曼哈頓距離、`free_move_per_action`、`move_range`、`extra_move_delay_per_cell`、`card_move_distance` + `ActionMoveUnit`、`enemy_intent_move {HOLD, APPROACH, RETREAT}`、`reachable_cells()`、`unit_moved` 訊號、訊號／枚舉只在尾端新增。
原則：**預設值一律保守＝不改變既有行為**（框架預設下沒有免費移動、沒有控制區、沒有場域格），全部由內容包的 `combat_rules_default` patch 與卡牌／敵人資料開啟。所有解析都是純函式（`BoardData` + 資料 → 格與單位），UI、AI、敵人意圖共用同一份，避免看到不同事實。

名詞：「行動」＝單位在時間軸輪到時做的一次操作；「刻」＝時間軸單位；「延遲 D」＝行動結束後 `wait = D × timeline_delay_scale ÷ speed`。

**整合修訂**：Phase 1 已實作的 Director 在 `_begin_action`／`_end_action` 依陣營分派到 `_begin_party_action`／`_begin_enemy_action` 與 `_end_party_action`／`_end_enemy_action`，行動延遲由 `CombatDirector._compute_action_delay` 單點計算；下文「`_begin_action` 重設移動點」落在主角與 AI 隊員的行動開始分派內，「`action_extra_delay` 併入延遲」落在 `_compute_action_delay`（與 `max(card_action_delay…)` 相加，用後歸零）。`unit_moved` 目前尚未在 `Signals` 宣告，隨 Phase 2 的 `ActionMoveUnit` 一起加。03 的 `reachable_cells(unit, range, ignore_occupancy) -> Array[Vector2i]` 以本檔 §1.1 的「可達格 → 路徑」回傳值取代。

## 1. 主動移動

### 1.1 規則定義

主動移動規則定義（條列）已抽到 [movement-active-rules.json](movement-active-rules.json)（5 列）。欄位：項目、規則。

### 1.2 資料／Action／Validator

```
CombatRulesData（尾端新增）
  move_adjacency: int = FOUR              # MOVE_ADJACENCY {FOUR, EIGHT}
  move_split_allowed: bool = true
  paid_move_max_cells: int = 0            # 0 = 不能付費移動
  move_pass_through_allies: bool = false
  move_pass_through_enemies: bool = false
  move_undo_allowed: bool = false
BaseCombatant（戰鬥內、不存檔）
  move_points: int                        # 行動開始時重設
  paid_cells_this_action: int
  cells_moved_this_action: int            # 含卡牌移動與強制位移？否——只算主動與卡牌移動（§5 用）
  ignores_occupancy: bool
  action_extra_delay: int                 # 付費移動累加；_end_action 併入延遲後歸零
CharacterData：character_ignores_occupancy: bool = false
BoardCellData：is_blocked: bool = false、move_cost: int = 1（§4）

ActionMoveUnit（Scripts 常數；values）
  mode: "TO_CELL" | "TOWARD" | "AWAY" | "TELEPORT"   # 預設 TO_CELL
  distance: int                           # TOWARD/AWAY 的最大格數；TO_CELL 時為路徑長度上限（-1 = 不限）
  target_cell: Vector2i                   # 未給時取 card_play_request.selected_cell
  reference: "SELECTED_TARGET" | "PARENT" | "NEAREST_OPPONENT" | "HERO"   # TOWARD/AWAY 的參照單位
  stop_at_distance: int = 1               # TOWARD 到達此距離即停
  consumes_move_points: bool = false
  use_path: bool = true                   # false = 直接放置（TELEPORT 強制 false）
  target_override 沿用：作用在 targets（預設 PARENT = 行動單位）
ActionGrantMovePoints：amount: int（可負）

ValidatorPathExists {to: "SELECTED_CELL"|cell, max_length}
ValidatorMovePoints {comparison_value, operator}
ValidatorCellFree {cell: "SELECTED_CELL", for_unit: "PARENT"}   # footprint 全空
```

`ActionMoveUnit` 走 `_intercept_action()`，狀態效果可攔截 `distance`（定身 → 0）。移動完成一次 `ActionMoveUnit` 發一次 `unit_moved(unit, from, to)`（路徑中途格不逐格發；格事件走 §4 的新訊號）。

### 1.3 與 CTB 的互動

| 移動種類 | 延遲 | 備註 |
|---|---|---|
| 免費移動點 | 0 | 不改 D |
| 付費移動 | 每格 `extra_move_delay_per_cell` 加到本次行動延遲（與出牌延遲**相加**，不取 max） | `action_delay = max(牌延遲…, default) + action_extra_delay` |
| 卡牌移動 | 牌自身 `card_action_delay` | 已含在 max 內 |
| 強制位移（§2） | 0 | 被位移者時間軸不變 |

修訂（實作 Phase 2）：延遲單位是「行動延遲」，換成刻數要再乘 `timeline_delay_scale ÷ speed`（付費 2 格 × 20 = +40 延遲，速度 10 下 = +400 刻）；Phase 2 尋路只做四向 BFS，`move_cost`／八向／穿越友軍／撤銷留到 2b。

### 1.4 AI

貪婪第 1 步的候選格＝`reachable_cells(unit, move_points + paid_move_max_cells)`；付費格的成本 = `extra_move_delay_per_cell × 格數 × ai_weights.save_energy`（沒有該軸則以 `0.01/刻` 折算）作負分。`move_split_allowed = false` 時 AI 一律先移後打。AI 隊員的卡牌移動由出牌迴圈的 preview 估「移動後可打到的目標數」決定。

### 1.5 UI（移動預覽）

- 行動單位有移動點時，`BoardView` 以 `reachable_cells` 高亮可達格（免費＝實色，付費＝斜紋並標 `+N 刻`）；懸停顯示路徑線；點擊即移動（`cell_clicked` 已在 spec）。
- 手牌拖曳中改顯示目標形狀，鬆手回到移動高亮。
- 時間軸條目在付費移動後即時重投影（`timeline_changed`）。

### 1.6 預設值

框架：`free_move_per_action 0`、`paid_move_max_cells 0`、`extra_move_delay_per_cell 0`、四向、不可穿越、不可撤銷。內容包典型：免費 1 格、付費 2 格 +20 刻／格、可穿越友軍。
