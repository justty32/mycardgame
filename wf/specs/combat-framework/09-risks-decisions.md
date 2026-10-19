# 風險與已決事項

[README](README.md)

## 6. 風險與開放問題

### 風險

風險六項已抽到 [risks.json](risks.json)（6 列，依原順序）。欄位：no（序號）、text（條文原文）。

### 已決（使用者 2026-10-19）

原六項開放問題全部已決；各決定的取捨記在 `wf/workflows/decisions.json`。

1. **遺物觸發歸屬**：每件遺物在資料指定（`artifact_trigger_scope`），未指定時歸主角。不需「指派持有者」UI。
2. **隊員倒下**：本場退場、戰後以 1 HP 回歸；主角倒下＝敗北。
3. **舊存檔**：不支援，拒絕載入並提示；不做 v1→v2 遷移（Phase 6 與 §3.7、§4.7 已改）。
4. **戰術指令介面**：第一版不做，`AiContext.commands` 恆為空；Phase 5 之後再加。
5. **戰前部署**：先用遭遇資料的預設格，不做部署 UI。
6. **框架 spec 落點**：`wf/specs/`（plan 放 `wf/plans/`）；`planning.md` 已補說明。
