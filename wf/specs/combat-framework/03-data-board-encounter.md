# 資料模型二：棋盤、遭遇、卡牌意圖、AI 傾向

[README](README.md)

## 3.1.3 棋盤與單位位置（戰鬥內，不存檔）

```
BoardData（RefCounted，由 CombatDirector 建立）
  size: Vector2i
  cells: Dictionary[Vector2i, BoardCellData]   # {occupant_uid, is_deploy_zone, tags[]}
  unit_cells: Dictionary[String, Array[Vector2i]]  # 大型單位佔多格
  func place(unit, anchor) / remove(unit) / move(unit, anchor)
  func distance(a: Vector2i, b: Vector2i) -> int（依 CombatRulesData.distance_metric）
  func cells_in_shape(origin, target, shape, pierce) -> Array[Vector2i]
  func units_in_cells(cells, faction_filter) -> Array[BaseCombatant]
  func reachable_cells(unit, range, ignore_occupancy) -> Array[Vector2i]
BaseCombatant
  + unit_uid: String
  + faction: int = {PARTY, ENEMY, NEUTRAL}
  + board_anchor: Vector2i
  + footprint: Vector2i
  + speed: int（getter；內容由狀態效果攔截器修飾，見 §3.6）
  + move_range: int
  + next_action_tick: int
  + last_action_tick: int
  + action_count: int
  + controller: BaseUnitController
```

## 3.1.4 遭遇與波次（讀取資料）

```
EncounterData extends SerializableData（SCHEMA: "encounters/"）
  encounter_board_size: Vector2i（< board_min_size 則報錯並夾到最小值）
  encounter_deploy_cells: Array[Vector2i]    # 空 = 預設南側兩列
  encounter_waves: Array[EncounterWaveData]（embedded）
    wave_units: Array[Dictionary]  # {"weights": {"enemy_id": w}, "cell": [x,y], "spawn_delay_ticks": int}
    wave_enter_delay_ticks: int
    wave_stagger_ticks: int
    wave_on_start_actions / wave_on_cleared_actions: Array[Dictionary]
  encounter_cell_texture_path / encounter_background_texture_path: String
EventData
  + event_encounter_object_id: String   # 空 = 由 event_weighted_enemy_object_ids 自動合成單波遭遇（北側一列、預設尺寸）→ 既有事件零改動
```

## 3.1.5 卡牌、意圖與目標

```
CardData 新增
  card_range: int = -1              # -1 = 不檢查距離（legacy）
  card_shape: int = SINGLE          # TARGET_SHAPES {SINGLE, ROW, COLUMN, CROSS, SQUARE_3, LINE, LINE_PIERCE, SELF_AREA, ALL, NONE}
  card_target_faction: int = OPPONENT   # {OPPONENT, ALLY, ANY, SELF, EMPTY_CELL}
  card_move_distance: int = 0       # 出牌附帶移動（0 = 無）；移動由 ActionMoveUnit 執行
  card_action_delay: int = -1       # -1 = rules.default_action_delay；行動延遲取本次行動所有已打出牌的最大值
  card_ai_hints: Dictionary = {}    # {"role": "damage|block|heal|buff|debuff|move|utility", "value_key": "damage", "danger": 0}
CardPlayRequest 新增
  acting_unit: BaseCombatant        # 取代 hand.player
  selected_cell: Vector2i
  resolved_targets: Array[BaseCombatant]   # 依形狀解析（HandManager._play_card 填）
EnemyIntentData 新增
  enemy_intent_range: int = -1
  enemy_intent_shape: int = SINGLE
  enemy_intent_target_rule: int = {NEAREST, FARTHEST, LOWEST_HP, HIGHEST_HP, HERO, RANDOM, MARKED, SELF}
  enemy_intent_move: int = {HOLD, APPROACH, RETREAT}   # 行動時先移動再判射程
  enemy_intent_action_delay: int = -1
EnemyData 新增
  enemy_speed: int = 10, enemy_move_range: int = 1, enemy_footprint: Vector2i = (1,1), enemy_ignores_occupancy: bool = false
BaseAction.TARGET_OVERRIDES 尾端新增（既有值保留；PLAYER 語意 = 主角、ALL_ENEMIES 語意 = 「parent 的對立陣營」）
  ACTING_UNIT, ALL_ALLIES, ALL_OPPONENTS, RANDOM_OPPONENT, RESOLVED_SHAPE, UNITS_IN_RANGE, MEMBER_UID
```

## 3.1.6 AI 傾向

```
AiProfileData extends SerializableData（SCHEMA: "ai_profiles/"）
  ai_weights: Dictionary[String, float]   # 任意具名軸，框架評分器用 role→weight 查表：{"damage":1,"block":0.6,"heal":0.8,"approach":0.3,"keep_distance":0,"save_energy":0,"risk":0}
  ai_thresholds: Dictionary[String, float] # {"heal_ally_below_ratio":0.5, "min_energy_to_play_big":2}
  ai_target_bias: Dictionary[String, float] # {"lowest_hp":1,"hero_marked":2,"nearest":0.5}
  ai_draft_weights: Dictionary[String, float] # 選牌獎／購卡用：role→weight，另加 "upgrade"、"duplicate_penalty"
  ai_position_weights: Dictionary[String, float] # {"near_hero":1,"between_hero_and_enemy":1,"far_from_enemy":0}
```
