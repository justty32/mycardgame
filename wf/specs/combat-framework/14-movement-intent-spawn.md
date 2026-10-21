# 移動規則四：敵人移動意圖與波次進場格（原移動草案 §6–§7）

[README](README.md)

**整合修訂**：Phase 1 已實作 `EnemyIntentController` 與 `CombatDirector.perform_enemy_intent`（`Enemy.build_intent_actions_data`），敵人意圖在進入等待時決定；`IntentResolver` 的移動解析插在意圖動作之前（先算 `planned_move_cell` 再執行意圖動作），`enemy_intent_move_after` 反之。`enemy_intent_action_delay` 已於 Phase 1 加入。波次進場的 `wave_*` 欄位隨 Phase 3 的 `CombatDirector._check_wave()` 實作；Phase 2 只做 `NEAREST_EMPTY`。修訂（實作 Phase 3）：三種策略已由 `UnitSpawner` 實作（取代 `_check_wave()` 的是 `WaveController`）；NEAREST_EMPTY 整張滿時依 retry 欄位等待、仍滿則跳過；跳過只記 log；預計格淡色標記未做。

## 6. 敵人移動意圖擴充

### 6.1 枚舉（尾端新增，既有值不動）

`enemy_intent_move {HOLD, APPROACH, RETREAT, KEEP_RANGE, FLANK, CHARGE, TELEPORT}`，附加欄位：

```
EnemyIntentData（尾端新增）
  enemy_intent_move_distance: int = -1      # -1 = 單位 move_range
  enemy_intent_preferred_range: int = -1    # KEEP_RANGE；-1 = enemy_intent_range
  enemy_intent_teleport_rule: int = ADJACENT_TO_TARGET   # {ADJACENT_TO_TARGET, FARTHEST_FROM_OPPONENTS, RANDOM_EMPTY, MARKED_CELL}
  enemy_intent_path_actions: Array[Dictionary] = []      # CHARGE 經過格上單位各執行（預設空）
  enemy_intent_move_after: bool = false     # true = 先執行意圖動作再移動（打了就跑）
```

修訂（實作 Phase 2）：`FLANK` 暫退 APPROACH、`TELEPORT` 暫退 HOLD（2b 實作）；CHARGE 未與目標同行／列時直接退化 APPROACH（不做一步對齊）；目標規則 RANDOM／MARKED 暫退 HERO；攻擊打不到時跳過並保留意圖到下次行動；ThreatPreview 每個敵人只計一次當前意圖。

### 6.2 定義（純函式 `IntentResolver.resolve(board, enemy, intent, target) -> {move_cell, path, targets, cells, can_hit}`）

各移動模式的目的格選擇與無合法格時行為（表）已抽到 [movement-intent-modes.json](movement-intent-modes.json)（7 列）。欄位：模式、目的格選擇（候選 = `reachable_cells(enemy, move_distance)`，含原地）、無合法格時。

全部決定性：候選排序（成本、y、x）後取首。`enemy_intent_move_after` 為 true 時先解析目標與動作再移動（RETREAT 典型用法：打完退）。

### 6.3 顯示

- 決定意圖時（進入等待）立刻算 `planned_move_cell` 與 `planned_path`；`unit_moved`／`unit_downed`／`timeline_changed` 後重算（既有 ThreatPreview.refresh）。
- 棋盤：懸停敵人或其時間軸條目時，除既有形狀高亮外，畫虛線路徑 + 半透明「幽靈」在 `planned_move_cell`；CHARGE 以整條直線高亮；TELEPORT 畫閃現圖示在目的格。意圖圖示旁小箭頭標明移動模式（內容包素材選填，缺省用框架箭頭）。
- `ThreatPreview` 把命中判定改為「從 planned_move_cell 出發」，確保頭上數字與實際一致。

### 6.4 CTB

敵人在 `move_range` 內移動免延遲；`extra_move_delay_per_cell` 不適用於敵人（`enemy_pays_move_delay = false`，不提供開關，保持簡單）。意圖延遲走既有 `enemy_intent_action_delay`。

### 6.5 AI 隊員

同一 `IntentResolver` 供 AI 評分「我站到此格後敵人下一步能否打到我」（ThreatPreview 已含）。無新增。

---

## 7. 波次進場格被佔

```
EncounterWaveData（尾端新增）
  wave_spawn_policy: int = NEAREST_EMPTY     # {NEAREST_EMPTY, WAIT_UNTIL_FREE, FAIL_SKIP}
  wave_spawn_retry_ticks: int = 50
  wave_spawn_max_retries: int = 4
EncounterData：encounter_spawn_zone_cells: Array[Vector2i]（空 = 北側兩列）
```

- `NEAREST_EMPTY`（預設）：以指定格為中心，依距離遞增找 footprint 全空且**非部署區**的 anchor；同距離先 spawn zone 內、再 y 小、再 x 小；找不到則全棋盤；整張都滿 → 轉 WAIT。
- `WAIT_UNTIL_FREE`：該單位 `spawn_delay_ticks += retry_ticks`，重試 `max_retries` 次後改 NEAREST_EMPTY；仍失敗 → 記 warning 並跳過（不阻擋勝利判定：`is_combat_over` 只看已生成與待生成數，待生成被跳過即不算）。
- `FAIL_SKIP`：直接跳過（給「若場上太擠就不來」的設計）。
- 同一規則給 `ActionSummonEnemies`（Phase 2「指定格或最近空格」就是 NEAREST_EMPTY）。
- 生成不觸發 `on_enter`（§4 預設），發 `unit_spawned`。
- UI：下一波進場前 `wave_enter_delay_ticks` 期間在預計格顯示淡色標記（Phase 3 選做）。
