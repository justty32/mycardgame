# 分階段計畫（§5）：Phase 1 CTB + 單一主角

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 1：CTB + 單一主角

可玩：一名主角 vs 多敵，依速度排隊。

### 改動

新 `CombatDirector.gd`、`CombatTimeline.gd`（優先佇列 + 投影）、`PlayerInputController.gd`；`Combat.gd` 刪回合流程、改 HUD；`CombatEndTurn` → `CombatEndAction`；`ActionEndTurn` 發新訊號；`Enemy` 改為進入等待時決定意圖（現 `Enemy.decide_next_intent`）；`EnemyData` + `enemy_speed`；`CharacterData` + `character_speed`；`CardData` + `card_action_delay`；`StatusEffectData` 尾端新增枚舉與 `status_effect_tick_interval`，`BaseCombatant.perform_status_effect_process_actions` 支援 `EVERY_N_TICKS`；`StatsHandler` 的 turn_count／is_player_turn 新語意 + `combat_tick`；`BaseArtifact`、`ArtifactEasyMode`、`ArtifactRetainHand`、`CardDecoratorDynamicValueModifier` 改連 `unit_action_*`；`TurnOverlay`；新 UI `TimelineBar.tscn/gd`（Root.tscn 加節點）；`ActionHandler._perform_actions`／`HandManager._perform_card_plays` 的 short-circuit 改問 Director。

**修訂（實作 Phase 1）**：另新增 `controllers/BaseUnitController.gd`、`EnemyIntentController.gd`（`CombatDirector.perform_enemy_intent` 用 `Enemy.build_intent_actions_data`）與 `Global.get_combat_director()`；`end_turn_requested` 保留為 `end_action_requested` 的舊別名（Director 兩者都聽），`perform_end_of_turn_hand_actions` 保留為 `perform_end_of_action_hand_actions` 的別名；`UnitRegistry` 註冊／取消時發 `unit_spawned`／`unit_removed`，召喚單位以「剛行動完」入列（next = now + wait）並在生成時決定意圖；與原文的偏差如下：

(a) `BaseArtifact`、`ArtifactEasyMode`、`ArtifactRetainHand`、`CardDecoratorDynamicValueModifier` 仍連 `player_turn_*`（語意已是「主角行動開始、抽牌前」，時點與舊版相同），改連 `unit_action_*` 與 `ArtifactData.artifact_trigger_scope` 延到 Phase 4 隨持有者概念一起做

(b) `turn_count` 由 `CombatDirector` 在主角行動開始、播動畫前呼叫 `StatsHandler.begin_hero_action()` 遞增，不靠抽牌後才發的 `unit_action_started`，讓抽牌統計與 TurnOverlay 一致

(c) `controller` 在 Phase 1 就型別為 `BaseUnitController`（原訂 Phase 4）

(d) `Global.are_remaining_enemies()` 與 `ActionHandler`／`HandManager` 的 short-circuit 不改，委派 `CombatDirector.has_living_opponents()`／`is_combat_over()` 延到 Phase 3 波次（Director 已提供兩者）

(e) `Combat.gd` 仍解析事件並經 `EnemyContainer` 生成敵人，再呼叫 `combat_director.begin_combat()`（原文要 Director 自己聽 `combat_started`；生成搬進 Director 在 Phase 2）

(f) `enemy_intent_action_delay` 已先加（原列 Phase 2 資料）

(g) 戰鬥結束仍由 `Combat.gd` 依敵人死亡動畫判定（`end_combat()` 每場只跑一次），Director 只在無存活對手時停迴圈

(h) 召喚敵人在生成時決定意圖，不等下次玩家回合開始（RNG 抽取時點只對召喚不同）

(i) `ValidatorEnemyAttacking`、`Player.update_incoming_damage`（ThreatPreview）留到 Phase 2；`CombatEndTurn` 類名已刪，mod 引用 `CombatEndTurn.END_TURN_QUEUE_IMMEDIACY` 須改 `CombatEndAction.END_ACTION_QUEUE_IMMEDIACY`（框架內只有 GlobalTestDataGenerator 引用過）。

### 規模與風險

規模：~900 行新增、~400 行刪除；18 檔 + Root.tscn。

風險：中高：AnimationPlayer 驅動的 `start_turn/end_turn` 動畫（舊 `Combat.gd` 回合流程，已移除）要改成 Director 播放再 await；`combat_flow.gd` 訊號計數需改；資源生命週期（Director 的 await 在 combat_ended／run_ended 後要能取消，沿 `ActionHandler._action_generation` 的世代做法）。

### Done when

新 `tests/ctb_flow.gd`（suite `Ctb`）：fixture 兩個敵人速度 20 與 5、主角 10，斷言前 8 筆行動順序與刻數、`combat_tick_advanced` 遞增、`EVERY_N_TICKS` 狀態觸發次數、格擋在行動開始清空、`turn_count` = 主角行動數；`combat_flow.gd` 改用新訊號後仍驗 14 傷害消 10 格擋等數值；`--suite All` 綠；`ResourceLifecycle` 綠（Director 退出無 leak）

**修訂（實作 Phase 1）**：`tests/ctb_flow.gd`＋`tests/ctb_fixture.gd`（suite `Ctb`，標記 `CTB PASS:`，排入 `All` 的 CombatDefeat 與 SaveLoad 之間；`tools/test-game.ps1` ValidateSet 加 `Ctb`）53 checks：seed 20261019、主角速度 10、敵人 fast 20／slow 5，前 8 筆 = fast@0、hero@0、slow@0、fast@500、fast@1000、hero@1000、fast@1500、fast@2000，`combat_tick_advanced` 0→500→1000→1500→2000，500 刻 `EVERY_N_TICKS` 狀態 10→8（刻 1000）→6（刻 2000），格擋 10→9→主角第二次行動開始歸 0，`turn_count` 2 = 主角 action_count（fast 3 次，之後 5 次），`is_player_turn` 只在主角行動中，TimelineBar 可見、TurnOverlay「Tick 1000 - Action 2」，中途 free 場景後無殘留 Director；`combat_flow.gd` 另斷言勝利路徑敵人 `unit_action_started/ended` 各 1 次且 End Turn 後刻 1000、敗北路徑致命敵人行動只 started 不 ended 且 Director 已停，舊數值契約（抽 5、能量 3、14 傷害消 10 格擋＋4 HP、`turn_count == 2`）不變；`python3 tools/test_game.py --suite All` 全綠（ResourceLifecycle 127、Dictionary 47、Smoke 82、CombatVictory 87、CombatDefeat 46、Ctb 53、SaveLoad write 28／read 56／rejected 73），pack 側寫 Smoke 60 checks、runner 合成測試 136、boundary lint 測試 19、new_pack 14 全過，boundary lint violations 0；TimelineBar 位置、TurnOverlay 文字、End Turn 啟用時機與動畫觀感需使用者實機確認；實際驗收見 [phase-1 plan](../../plans/combat-framework/phase-1.md)。

### agent

普通（opus）寫 Director/Timeline 與訊號遷移；雜活（sonnet）改 artifacts/decorator/TurnOverlay 等機械替換
