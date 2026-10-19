# 移動規則二：強制位移與控制區（原移動草案 §2–§3）

[README](README.md)

## 2. 強制位移

### 2.1 規則定義

強制位移規則定義（條列）已抽到 [movement-displace-rules.json](movement-displace-rules.json)（10 列）。欄位：項目、規則。

### 2.2 資料／Action／Validator

```
CombatRulesData（尾端新增）
  displace_tie_axis: int = VERTICAL       # DISPLACE_TIE_AXES {VERTICAL, HORIZONTAL}
  displace_max_footprint_area: int = 1
BaseCombatant
  is_immovable: bool = false
  displace_resistance: int = 0
  cells_displaced_this_action: int
EnemyData：enemy_is_immovable、enemy_displace_resistance
CharacterData：character_is_immovable、character_displace_resistance

ActionDisplaceUnit（values；targets = 被位移者，預設 SELECTED_TARGETS）
  mode: "PUSH" | "PULL" | "PULL_ADJACENT" | "SWAP" | "TO_CELL"
  distance: int = 1
  origin_cell: Vector2i                   # 未給 = parent.board_anchor
  collision_damage_per_cell: int = 0
  collision_damage_to_blocker: int = 0
  delay_on_collision: int = 0
  bypass_block: bool = false
  ignore_resistance: bool = false
執行後在 card_play_request.card_values 寫 "displaced_cells"（實際位移格數）與 "collided"（bool），供後續動作用（同 unblocked_damage 模式）。

StatusEffect 範例（框架測試資料）：status_rooted —— 攔截 ActionMoveUnit/ActionDisplaceUnit 的 distance → 0。
ValidatorDisplaceable {target}   # 非 immovable 且 footprint 面積 ≤ 上限
```

### 2.3 與 CTB 的互動

位移本身 0 延遲；`delay_on_collision` 直接改被位移者 `next_action_tick` 並發 `timeline_changed`。位移後敵人意圖由 `ThreatPreview.refresh()` 重解析（既有規則 1）。

### 2.4 被封鎖的位移

`StatusEffectData` 新增兩個框架旗標（透過攔截器實作，不加欄位）：`teleport_blocked`（讓 TELEPORT／SWAP 的 Validator 失敗）、`rooted`。場域格也可帶 `field_blocks_teleport_into`（§4）。

### 2.5 AI

`card_ai_hints.role = "displace"`；估值 = preview 的碰撞傷害 + Δ威脅（把被位移者推出其意圖射程 → 該意圖對我方的 ThreatPreview 數值降幅）+ 推入危險格的 preview 傷害（§4）。Phase 2 先只算前兩項，第三項在場域格階段補。敵人意圖同樣可用 `ActionDisplaceUnit`（意圖動作就是 Action），意圖預覽把「預計把誰推到哪」畫成箭頭。

### 2.6 預設值

碰撞傷害 0、多格不可位移、tie 軸垂直、無抗性。

---

## 3. 控制區／攔截（可選規則）

### 3.1 規則定義

`rules.zone_of_control`（預設 `NONE`）：
- `NONE`：無。
- `EXTRA_MOVE_COST`：離開「與任一敵對單位相鄰」的格，該步額外 +`zoc_extra_move_cost`（預設 1）移動點；進入尋路成本（BFS 改 Dijkstra）。
- `OPPORTUNITY_ATTACK`：離開相鄰格時，每個相鄰敵對單位對離開者執行其 `opportunity_actions`（`EnemyData.enemy_opportunity_actions`／`CharacterData.character_opportunity_actions`，預設空＝無事發生），每個攻擊者對同一離開者每次行動最多一次。
- `ignores_zoc`（單位層，飛行預設 true 與 `ignores_occupancy` 綁定，也可獨立設）免疫兩種模式。
- 強制位移預設不觸發（`zoc_triggers_on_forced_move = false`）；卡牌移動觸發（可用 `ActionMoveUnit.ignore_zoc = true` 豁免）。

### 3.2 資料

```
CombatRulesData：zone_of_control: int = NONE（ZOC_MODES {NONE, EXTRA_MOVE_COST, OPPORTUNITY_ATTACK}）、zoc_extra_move_cost: int = 1、zoc_triggers_on_forced_move: bool = false
BaseCombatant：ignores_zoc: bool = false、opportunity_actions: Array[Dictionary]（來自資料）
Signals：unit_left_zoc(mover, controller)（尾端新增；測試可觀察）
```

### 3.3 CTB／AI

`EXTRA_MOVE_COST` 不改延遲（成本已在移動點）。`OPPORTUNITY_ATTACK` 的動作即時執行、不改時間軸。AI：Dijkstra 成本自然納入；借機攻擊以 preview 估傷害，從該格 `pos_score` 扣除 `threat` 權重。

### 3.4 預設

`NONE`。建議延後實作（§9）。
