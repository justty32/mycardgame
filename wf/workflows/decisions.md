# decisions — 決策記錄（為什麼選 A 不選 B）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

留下「為什麼」：git log 找得回改了什麼，找不回**為什麼放棄方案 C**。

**何時用**：在兩個以上可行方案裡選一個，且日後可能被問「當初為什麼」。
**何時不用**：只有一條路，或隨時可回頭的小事。決策過程需結構化評估時，先在對話或 investigation 整理（decide 工作流未導入），結論再落到這裡。

## Done when

- decisions.json 追加一列，且 `rejected_and_why`、`premise` 兩欄非空。

## 記錄

已抽到 [decisions.json](decisions.json)（24 列，依時間追加，新的在最後）。

欄位：
- `date`：決定日期（YYYY-MM-DD）。
- `decision`：選了什麼。
- `rejected_and_why`：未選方案與原因。
- `premise`：前提，變了就重看。

統計：24 筆；2026-10-19 有 17 筆，2026-10-20 有 4 筆，2026-10-21 有 3 筆。

