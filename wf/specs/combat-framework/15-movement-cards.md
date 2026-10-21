# 移動規則五：卡牌移動關鍵字與 Action 積木（原移動草案 §8）

[README](README.md)

## 8. 卡牌移動類關鍵字與 Action 積木

### 8.1 關鍵字（框架 `keywords/` 測試資料提供，內容包可換名）

卡牌移動類關鍵字（表）已抽到 [movement-keywords.json](movement-keywords.json)（12 列）。欄位：關鍵字、語意、實作。

### 8.2 卡牌 JSON 範例（patch 格式，只列新／關鍵欄位；id 為框架測試用）

```json
{ "object_id": "card_test_dash_strike",
  "properties": {
    "card_name": "Dash Strike", "card_energy_cost": 1, "card_action_delay": 100,
    "card_range": 3, "card_shape": 5, "card_target_faction": 0,
    "card_values": {"damage": 6, "distance": 2, "stop_at_distance": 1},
    "card_play_validators": [{"res://scripts/validators/ValidatorInLine.gd": {}}],
    "card_play_actions": [
      {"res://scripts/actions/board_actions/ActionMoveUnit.gd": {"mode": "TOWARD", "reference": "SELECTED_TARGET"}},
      {"res://scripts/actions/combatant_actions/ActionAttackGenerator.gd": {"action_validators": [{"res://scripts/validators/ValidatorDistance.gd": {"operator": "<=", "comparison_value": 1}}]}}
    ],
    "card_ai_hints": {"role": "damage", "value_key": "damage", "danger": 0}
  }}

{ "object_id": "card_test_shove",
  "properties": {
    "card_name": "Shove", "card_energy_cost": 1, "card_range": 1, "card_shape": 0, "card_target_faction": 0,
    "card_values": {"damage": 4, "distance": 2, "collision_damage_per_cell": 3},
    "card_play_actions": [
      {"res://scripts/actions/combatant_actions/ActionAttackGenerator.gd": {}},
      {"res://scripts/actions/board_actions/ActionDisplaceUnit.gd": {"mode": "PUSH"}}
    ],
    "card_ai_hints": {"role": "displace", "value_key": "damage"}
  }}

{ "object_id": "card_test_blink",
  "properties": {
    "card_name": "Blink", "card_energy_cost": 0, "card_action_delay": 50,
    "card_range": 3, "card_shape": 0, "card_target_faction": 4,
    "card_play_actions": [{"res://scripts/actions/board_actions/ActionMoveUnit.gd": {"mode": "TELEPORT"}}],
    "card_ai_hints": {"role": "move", "value": 2}
  }}

{ "object_id": "card_test_caltrops",
  "properties": {
    "card_name": "Caltrops", "card_energy_cost": 1, "card_range": 2, "card_shape": 3, "card_target_faction": 4,
    "card_values": {"field_id": "field_test_spikes", "duration_override": 300},
    "card_play_actions": [{"res://scripts/actions/board_actions/ActionCreateField.gd": {}}],
    "card_ai_hints": {"role": "debuff", "value": 3}
  }}
```

修訂（實作 Phase 2）：ActionHandler 以堆疊執行，`card_play_actions` 由最後一項先跑，上例的順序在框架測試資料中反向列出（移動列在攻擊之後）；框架沒有 `action_validators` 鍵，突進的「相鄰才攻擊」用 ActionValidator 包住攻擊；閃現以 ValidatorCellFree＋ValidatorPathExists{teleport} 驗證。

`card_shape` 數字對應 spec 的 `TARGET_SHAPES` 順序（SINGLE 0、ROW 1、COLUMN 2、CROSS 3、SQUARE_3 4、LINE 5…）；`card_target_faction` 依 `{OPPONENT 0, ALLY 1, ANY 2, SELF 3, EMPTY_CELL 4}`。`card_ai_hints.value` 是沒有 preview 數值的移動類牌的固定估值。

新 Action 放 `game/scripts/actions/board_actions/`，Validator 放 `game/scripts/validators/board/`，都登記進 `Scripts` 常數。
