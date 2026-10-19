# 風險與已決事項

[README](README.md)

## 6. 風險與開放問題

### 風險

風險六項已抽到 [risks.json](risks.json)（6 列，依原順序）。欄位：no（序號）、text（條文原文）。

### 後續待補（開放問題，來自題材回饋，不阻擋 Phase 2；2026-10-19）

題材層移動設計（概念草案）回饋五項框架缺口，尚未決定、尚未排入階段：

1. 意圖目標規則 `enemy_intent_target_rule` 尾端加 `NEAREST_ALLY`（單位貼近己方陣營中最近者）與 `HIGHEST_VALUE(key)`（取某狀態／數值最高者為目標）。
2. 「對友軍保距」：`KEEP_RANGE` 的參照單位目前只能是對手；需評估讓參照可指定己方單位（過渡做法：用進場格加 `HOLD` 代替）。
3. 單位縮放佔格：需 `BoardData.resize_footprint(unit, new_footprint)`，保留 anchor、釋放多餘格（如多格單位依血量縮成單格）。
4. 「代受」類效果屬狀態／攔截器層加場域 tag 查詢的組合，不是移動規則；框架只需確保場域 tag 可被查詢（`BoardData.get_fields(cell, tag)`）。
5. 「沿途穿越並作用」（如衝鋒途中對經過單位生效）依賴 `enemy_intent_path_actions`／`UNITS_IN_PATH`，屬 Phase 2b；Phase 2 先退化為「停在首個單位前並作用於它」。

### 已決（使用者 2026-10-19）

原六項開放問題全部已決；各決定的取捨記在 `wf/workflows/decisions.json`。

1. **遺物觸發歸屬**：每件遺物在資料指定（`artifact_trigger_scope`），未指定時歸主角。不需「指派持有者」UI。
2. **隊員倒下**：本場退場、戰後以 1 HP 回歸；主角倒下＝敗北。
3. **舊存檔**：不支援，拒絕載入並提示；不做 v1→v2 遷移（Phase 6 與 §3.7、§4.7 已改）。
4. **戰術指令介面**：第一版不做，`AiContext.commands` 恆為空；Phase 5 之後再加。
5. **戰前部署**：先用遭遇資料的預設格，不做部署 UI。
6. **框架 spec 落點**：`wf/specs/`（plan 放 `wf/plans/`）；`planning.md` 已補說明。
