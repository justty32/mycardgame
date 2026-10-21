> 封存 2026-10-21，由 已完成（Phase 3 與 Phase 2b）；現況見 wf/specs/dual-board/README.md 取代

# 分階段計畫（§5）：Phase 3 波次與 Phase 2b 場域格／控制區

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 3：波次

可玩：一場遭遇兩波。

### 改動

`CombatDirector._check_wave()`、`wave_started/cleared`、登場延遲與錯開插入時間軸、`wave_on_*_actions`；`is_combat_over` 改看最後一波；`WaveLabel` UI；`Global.are_remaining_enemies()` 委派。

**修訂（實作 Phase 3）**：先把 `CombatDirector` 拆出 `BoardController`（棋盤、部署、放置、點格移動）、`UnitSpawner`（波次單位與召喚、待進場佇列、進場格策略）、`CombatActionPhases`、`CombatStartActions`，意圖執行移到 `EnemyIntentController.perform_intent`（Director 留委派）；新增 `WaveController`（取代原文的 `_check_wave()`）。偏差如下：

(a) 清波＝本波單位都已進場（或被跳過）且無存活非雜兵敵人；檢查在擊殺後動作佇列清空時、與每批進場後做，不在每次行動後

(b) 勝利仍在敵人死亡動畫結束時判定（舊時點），改由 Director 的 WaveController 判「最後一波清空」後呼叫 `Combat.end_combat()`，`Combat.gd` 的「只剩雜兵」判定刪除；因跳過而清空最後一波時直接結束

(c) short-circuit 不改呼叫點：`Global.are_remaining_enemies()` 委派 `CombatDirector.has_remaining_opponents()`（存活敵人含雜兵，或尚有後續波次／待進場單位），`is_combat_over()` 也改用它，不用原文的 `is_combat_over()` 當 short-circuit 條件，以保留「雜兵存活時不短路」的舊行為

(d) 雜兵：不擋清波、留到下一波繼續行動、最後一波清空時戰鬥照舊結束（雜兵存活）；第 0 波只在擊殺時檢查，全雜兵遭遇仍在第一次擊殺後結束（舊行為），後續全雜兵波在進場完即清空

(e) 第 0 波在開戰時就放上棋盤，首次行動刻＝enter_delay + stagger×序號 + spawn_delay；後續波在進場刻才生成並在該刻行動，敵人 id 於排程時依序抽

(f) `WAIT_UNTIL_FREE`／`FAIL_SKIP` 自 Phase 2b 提前到 Phase 3（第 0 波也適用；WAIT 於第 0 波會改由自動容器在重試刻生成）；跳過只印 log（不 push_error）

(g) `WaveLabel` 是 TimelineBar 執行時建立的 Label（「Wave i/n」，只在多波遭遇顯示），預計格淡色標記未做

(h) `CombatDirector` 仍約 445 行（迴圈、生命週期、玩家結束行動閘、委派），未再拆。

### 規模與風險

規模：~300 行；5 檔。

風險：低；注意波間 `ActionHandler` short-circuit 與 `HandManager._perform_card_plays` 的「無敵人即清佇列」。

### Done when

新 `tests/wave_flow.gd`（suite `Wave`）：第 1 波清空後 `wave_cleared(0)`、第 2 波單位在指定刻進場、波間打出的格擋牌不被短路、第 2 波清空才 `combat_ended`；獎勵按波數累計可由 `wave_on_cleared_actions` 加錢驗證

**修訂（實作 Phase 3）**：`tests/wave_flow.gd`＋`wave_cases.gd`＋`wave_fixture.gd`（suite `Wave`，標記 `WAVE PASS:`，All 中排在 Board 與 SaveLoad 之間）48 checks：三波遭遇（第 1 波 WAIT_UNTIL_FREE、第 2 波 FAIL_SKIP、每波清空加 10 錢），wave_cleared(0)@0、波間無存活敵人時 `are_remaining_enemies()` 仍真且格擋牌照常生效、wave_started(1)@300、雜兵 (0,0)@300、被佔格的單位在 400／450 等待後於 500 進最近空格 (1,0)、雜兵存活時 wave_cleared(1)@1000、wave_started(2)@1200 並跳過被佔格單位、wave_cleared(2) 後才 combat_ended、錢 +30；CombatVictory 另斷言舊單波遭遇依序 wave_started(0)、wave_cleared(0)、combat_ended（90 checks）；實際驗收見 [phase-3 plan](../../plans/combat-framework/phase-3.md)。

### agent

普通（opus）

## Phase 2b：場域格與控制區

可玩：（原文未列；依 Done when：戰鬥中場域與控制區可觸發）。

狀態：**已完成**（9ced42f，suite `Field`；驗收記錄已封存，現況見 [README 的方向更新](README.md#方向更新雙盤-a-與可選棋盤模組取代-g4-原文) 所連的雙盤契約）。排在 Phase 3（波次）之後、Phase 4（AI 隊員）之前，讓 AI 的 `pos_score` 一開始就能看到場域與控制區。

### 改動

依 [12-movement-displace-zoc.md](12-movement-displace-zoc.md)、[13-movement-fields-position.md](13-movement-fields-position.md)、[08-phases.md 的移動增補分配](08-phases.md#移動增補的階段分配原移動草案-9) 的「之後」欄：控制區（`zone_of_control` 的 `EXTRA_MOVE_COST`／`OPPORTUNITY_ATTACK`）、場域 `FieldData`／`FieldInstance` 全套與 `ActionCreateField`／`ActionRemoveField`／`ActionSetCellBlocked`／`ValidatorCellHasField`／`UNITS_ON_FIELD`、`ValidatorFlanked`／`ValidatorAdjacentUnits`／`is_flanked`、`FLANK`／`TELEPORT`／`path_actions`／`move_after`、`WAIT_UNTIL_FREE`／`FAIL_SKIP`、八向／撤銷／穿越友軍、`displace_resistance`／多格位移／`delay_on_collision`；排在 Phase 3 之後、Phase 4 之前，讓 AI 的 `pos_score` 一開始就能看到場域與控制區；掛在既有 tick／移動訊號上。

**修訂（實作 Phase 3）**：`WAIT_UNTIL_FREE`／`FAIL_SKIP` 已在 Phase 3 實作，2b 不再包含。

### 規模與風險

規模：~500 行、8 檔。

風險：低中；純新增，掛在既有 tick／移動訊號上。

### Done when

`tests/field_flow.gd`（suite `Field`）——建立 300 刻場域、進入觸發一次、停留在行動開始觸發、過期移除、`field_blocks_movement` 阻擋尋路、`EXTRA_MOVE_COST` 讓可達格集合縮小、`OPPORTUNITY_ATTACK` 對離開者造成 preview 相同傷害、強制位移不觸發控制區但觸發場域進入。

### agent

（原文未列；整合時沿用同類分工）普通（opus）：場域觸發時點與控制區；雜活（sonnet）：欄位與測試資料
