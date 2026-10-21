# 風險與已決事項

[README](README.md)

## 6. 風險與開放問題

### 風險

**（1）****雙真相期**（Phase 4–6）：proxy 讓舊碼能跑但可能寫錯對象；以 `party_data_regression.gd` 與 Phase 6 的 rg 歸零把關。

**（2）****Await 生命週期**：Director 的長 await 迴圈在 `run_ended`／`combat_ended` 時必須以世代號取消，否則重現 05 報告修過的退出保留；`ResourceLifecycle` suite 每階段都跑。

**（3）****狀態效果枚舉重釋**：舊 JSON 的 `status_effect_action_process_times` 整數不可重排；新語意（合併敵方回合前後與意圖前後）可能讓某些測試資料的狀態觸發兩次——Phase 1 要盤點 `GlobalTestDataGenerator` 的狀態定義。

**（4）****AI 估值成本**：preview 攔截每次建立攔截鏈，若手牌×目標組合大可能造成單幀卡頓；先量測，必要時改為分幀（`await process_frame`）。

**（5）****runner 衝突**：另一 agent 正改 `tools/test_game.py`／`framework_smoke.gd`；本 spec 的 suite 新增排在其 commit 之後。

**（6）****`example_mod` 與教學**：mods 的卡沒有新欄位，靠預設值（range -1、shape SINGLE、faction OPPONENT）維持可玩；教學文件要補「新欄位預設即舊行為」。

### 後續待補（開放問題，來自題材回饋，不阻擋 Phase 2）

題材層移動設計（概念草案）回饋五項框架缺口，尚未決定、尚未排入階段：

1. 意圖目標規則 `enemy_intent_target_rule` 尾端加 `NEAREST_ALLY`（單位貼近己方陣營中最近者）與 `HIGHEST_VALUE(key)`（取某狀態／數值最高者為目標）。
2. 「對友軍保距」：`KEEP_RANGE` 的參照單位目前只能是對手；需評估讓參照可指定己方單位（過渡做法：用進場格加 `HOLD` 代替）。
3. 單位縮放佔格：需 `BoardData.resize_footprint(unit, new_footprint)`，保留 anchor、釋放多餘格（如多格單位依血量縮成單格）。
4. 「代受」類效果屬狀態／攔截器層加場域 tag 查詢的組合，不是移動規則；框架只需確保場域 tag 可被查詢（`BoardData.get_fields(cell, tag)`）。
5. 「沿途穿越並作用」（如衝鋒途中對經過單位生效）依賴 `enemy_intent_path_actions`／`UNITS_IN_PATH`，屬 Phase 2b；Phase 2 先退化為「停在首個單位前並作用於它」。

### 已決

原六項開放問題全部已決；決定與取捨的單一來源是 [decisions.json](../../workflows/decisions.json) 第 12–17 列，本 spec 只記落在哪些欄位與章節：

- 第 12 列 遺物觸發歸屬：欄位 `artifact_trigger_scope`（見 [listener-migration.json](listener-migration.json)）。
- 第 13 列 隊員倒下：`downed_member_policy` 預設 `REVIVE_AFTER_COMBAT_1HP`、`hero_down_ends_run=true`（見 [§3.2 迴圈要點（6）](04-combat-loop-signals.md#迴圈要點)）。
- 第 14 列 舊存檔：Phase 6（[08f](08f-phase-4-6.md#phase-6存檔版本拒絕與收尾)）、§3.7（[06](06-meta.md#存檔版本)）、§4.7（[07](07-tradeoffs.md)）已照改。
- 第 15 列 戰術指令：`AiContext.commands` 恆為空（[05](05-intent-and-ai.md)）。
- 第 16 列 戰前部署：用 `encounter_deploy_cells`（[§3.2](04-combat-loop-signals.md)）。
- 第 17 列 框架 spec 落點：`wf/specs/`、`wf/plans/`；[planning](../../workflows/planning.md) 已補說明。
