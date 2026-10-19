# 移動規則三：格子屬性、場域格與位置條件（原移動草案 §4–§5）

[README](README.md)

## 4. 格子屬性與場域格

### 4.1 規則定義

格子屬性與場域規則定義（條列）已抽到 [movement-field-rules.json](movement-field-rules.json)（6 列）。欄位：項目、規則。

### 4.2 資料／Action

```
FieldData extends SerializableData（SCHEMA "fields/"）
  field_name, field_color_id, field_icon_texture_path
  field_duration_ticks: int = -1
  field_tick_interval: int = 0            # 0 = 無 every_n_ticks
  field_faction_filter: int = ANY
  field_stack_policy: int = REPLACE
  field_blocks_movement: bool = false
  field_blocks_teleport_into: bool = false
  field_move_cost_override: int = -1
  field_triggers_on_pass_through: bool = false
  field_on_enter_actions / field_on_leave_actions / field_on_stay_actions / field_tick_actions: Array[Dictionary]
  field_tags: Array[String]
FieldInstance（RefCounted）：field_data, cell, owner_uid, created_tick, expires_tick, stacks
BoardData：fields: Dictionary[Vector2i, Array[FieldInstance]]；get_fields(cell, tag="")；is_cell_enterable(cell, unit)
BoardCellData：is_blocked, blocks_line, move_cost, tags（既有 tags）
EncounterData：encounter_blocked_cells: Array[Vector2i]、encounter_initial_fields: Array[Dictionary] {"field_id", "cells":[[x,y]...]}

ActionCreateField（values）：field_id、cells（省略 = 依 card_shape 解析的格；"SELECTED_CELL"；"PARENT_CELL"）、duration_override、owner = PARENT
ActionRemoveField（values）：field_id 或 tag、cells（省略 = 全場）
ActionSetCellBlocked（values）：cells、blocked: bool（給「生成／摧毀障礙」事件）

Signals（尾端新增）：unit_entered_cell(unit, cell)、unit_left_cell(unit, cell)、field_created(instance)、field_removed(instance)
ValidatorCellHasField {cell, field_id|tag, invert}
TARGET_OVERRIDES 尾端新增：UNITS_ON_FIELD（values.field_id/tag）
```

### 4.3 CTB

時長與 tick 全部以刻計，掛在 `combat_tick_advanced`；若一次推進跨過多個 interval 邊界，依序補發（與 `EVERY_N_TICKS` 狀態同規則）。`on_stay` 掛在單位行動，確保「站著不動」有代價。

### 4.4 AI

`pos_score` 加特徵 `hazard(c)` = 該格所有場域 `on_enter + on_stay` 動作的 preview 傷害（對本單位陣營有效者），權重 `ai_position_weights.avoid_hazard`（預設 1），正向場域（治療／格擋）取負值。AI 出「生成場域」牌：估值 = 覆蓋格上敵對單位數 × 每人 preview 數值。

### 4.5 UI

格底色依 `field_color_id`、角落圖示、懸停顯示剩餘刻；障礙格用 `encounter_cell_texture_path` 的 blocked 變體（內容包素材選填）。

### 4.6 預設

無障礙、無場域；所有旗標 false。

---

## 5. 位置相關條件與效果

不引入「朝向」（facing）——曼哈頓棋盤上沒有可靠朝向，背刺以**夾擊**定義；若日後要朝向，再加 `unit_facing`（移動時依最後一步方向更新）與 `ValidatorRelativeFacing`。

### 5.1 條件（Validator，可用於 `card_play_validators`、action validators、glow）

```
ValidatorDistance {from: "PARENT", to: "SELECTED_TARGET"|"HERO"|"NEAREST_OPPONENT", operator, comparison_value}
ValidatorAdjacentUnits {around: "PARENT"|"SELECTED_TARGET", faction: "ALLY"|"OPPONENT"|"ANY", operator, comparison_value}   # 相鄰友軍加成、被包圍
ValidatorFlanked {target: "SELECTED_TARGET", mode: "PINCER"|"SURROUND"}   # PINCER：攻擊者與另一友軍在目標相對兩側；SURROUND：目標相鄰敵對 ≥ comparison_value
ValidatorCellsMoved {operator, comparison_value}   # 本次行動已主動／卡牌移動格數
ValidatorInLine {from: "PARENT", to: "SELECTED_TARGET"}   # 同行或同列
ValidatorOnEdge {unit}
ValidatorCellsMoved 用 BaseCombatant.cells_moved_this_action（§1）
```

### 5.2 數值隨位置變化（不新增攔截器類別）

`ActionComputeBoardValue`（放在 `card_play_actions` 最前）：把棋盤量寫進 `card_play_request.card_values`，鍵名固定：`distance`（parent→第一個 target）、`adjacent_allies`、`adjacent_opponents`、`target_adjacent_opponents`、`cells_moved_this_action`、`cells_displaced_this_action`、`is_flanked`（0/1）。後續動作沿既有值層級（Action → CardPlayRequest → CardData）用 `custom_key_names` 或既有動態值修飾器讀取，例如「每距離 1 格 +2 傷害」＝ `ActionAttackGenerator` 的 `damage` 由 `CardDecoratorDynamicValueModifier` 以 `distance × 2` 修飾。

- **直線上第一個單位**：既有 `LINE`（非穿透）；`blocks_line` 格（§4）截斷。
- **「移動過 N 格後」觸發**：`ValidatorCellsMoved`；持續型「每次移動時…」用 `card_listeners` 監聽 `unit_moved`（既有 listener 機制，filter `unit == parent`）。
- **距離越遠傷害變化**：`distance` 鍵 + 修飾器（遞減時 clamp 由修飾器的 min 處理）。
- **相鄰友軍加成**：`adjacent_allies` 鍵。
- **夾擊**：`is_flanked` 鍵或 `ValidatorFlanked`。

### 5.3 CTB／AI

條件不影響時間軸。AI：這些值由 preview 攔截自然算出（preview 在候選格上執行 `ActionComputeBoardValue` 時用「假設 anchor」—— `AiContext` 提供 `hypothetical_anchor` 讓 `BoardData.distance` 查詢改讀）。
