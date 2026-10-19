# planning — 想法成熟管線（idea → roadmap → 詳規 → 執行）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

從萌芽到動工的四階段收在**同一條管線**，不拆成四個工作流——免得卡在「這算 idea 還是 roadmap」。

**何時用**：使用者說「記個想法」「以後要做」「排進 roadmap」「幫我規劃」。
**何時不用**：三兩步的小事直接做；已有 spec / plan 且在動工 → 執行工作流；只是要調查清楚 → investigation（dev 包）。

## Done when

- idea / roadmap：對應表多一列，或既有列狀態欄更新。
- 詳規：spec 有「方案 / 取捨」段、plan 有「步驟 / 驗證」段；動工完成後移 `archive/`。

## 階段

| 階段 | 回答的問題 | 落點 |
|------|-----------|------|
| **idea** | 要不要做？ | 下方「想法」表 |
| **roadmap** | 會做，何時？ | 下方「roadmap」表 |
| **詳規** | 怎麼做？ | 開發：**spec**（方案）→ **plan**（動工前詳規），各一檔放 `planning/specs/`、`planning/plans/`，第一份出現時升級成資料夾型。非開發：目前未導入對應流程，先在 idea／roadmap 記錄|
| **執行** | — | 開發：feature-dev；非開發：未導入 |

## 想法（要不要做）

| 想法 | 一句話 | 狀態（想想 / 會做→搬 roadmap / 不做＋原因）|
|------|--------|------------------------------------------|

## roadmap（會做，何時）

| 事項 | 何時 / 順序 | 前提 |
|------|------------|---------|
| 定義原創玩法與最小可玩內容 | 框架基準後 | 決定核心玩法，再依 game-flow 建立新局、選擇、戰鬥／非戰鬥、結算與續玩的最小閉環 |

框架已匯入、修復 Dictionary 與資源生命週期並建立流程回歸，見 [當前驗證](../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。上表仍屬後續玩法方向，基準測試通過不代表原創內容已完成；落地順序見 [整體遊戲流程](game-dev/game-flow.md)。

## 交接

遊戲詳規由 agent 依目前需求維護，至少說清楚玩家可觀察的行為、影響資料／機制／UI、既有存檔影響、實作範圍與驗收證據。簡單改動可直接記在任務；跨系統或長任務才建立 spec／plan，不為一般工程決策新增確認關卡。

執行時接 [game-dev](game-dev/README.md)；完成後將穩定操作與可重複經驗整理到 [learning](learning.md) 指定的位置，規劃筆記不取代現行工作流。

- 決定「為什麼選 A 不選 B」 → [decisions](decisions.md)。卡在使用者 → [WAIT_USER](../WAIT_USER.md) 一行；跨 session → [SESSION-LOG](../SESSION-LOG.md) 一行。
