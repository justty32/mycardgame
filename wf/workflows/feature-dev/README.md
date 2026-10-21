# feature-dev — 功能開發 / 修 bug（工作流入口）

[WORKFLOWS](../../WORKFLOWS.md)｜[INDEX](../../INDEX.md)

改變行為的工作：加一個功能、修一個 bug，從動手到驗證交付。碰原始碼前先讀 [common/conventions](../common/conventions.md) 與 [common/code-map](../common/code-map.md)。

**何時用**：tools／wf 類非遊戲工作要「開發／修改某個功能」「這裡壞了，修一下」——**修 bug 也走這條**，產出一樣是「行為改變＋驗證綠燈」。
**何時不用**：遊戲需求（內容、機制、UI、上游，含修遊戲 bug）→ [game-dev](../game-dev/README.md)，其流程節已含同樣的四步迴圈；只是要查清楚原因、還不動碼 → [investigation](../investigation.md)；行為不變、只重排結構 → [refactor](../refactor/README.md)；還在討論要不要做、方案長怎樣 → [planning](../planning.md)。

## Done when

- [testing](../testing.md) 標「改完必跑」的驗證指令回傳 0。
- 新行為具有 [validation](../game-dev/validation.md) 對應的驗收證據；不能只以既有 smoke 通過代替功能測試。
- [common/code-map](../common/code-map.md) 中該領域的列已更新（新增／刪除的檔、職責變動、測試位置）。
- 要使用者實機驗證的在 [WAIT_USER](../../WAIT_USER.md) 有一行；跨 session 沒收尾的在 [SESSION-LOG](../../SESSION-LOG.md) 有一行。

## 流程

```
讀 code map 找到相關領域（只讀清單裡的檔）
  → 增量修改（守 conventions）
  → 跑 testing 的自動驗證，綠燈
  → 要實機／實環境的交使用者驗證 → 回報問題 → 修 → 重複
  → 全數通過後：更新 code map → 補文檔 → 交付（commit 依使用者指示）
```

- 自動驗證由 agent 執行；缺少環境時先補齊或明列限制。文件 lint 不代表遊戲驗證。
- 迭代期間 code map / 文檔可暫時落後，**commit 前必須對齊**；跨 session 時在 [SESSION-LOG](../../SESSION-LOG.md) 補一行 `[功能名] 文檔 / code map 待同步`，下個 session 才不會誤判已同步。
- 交付前先核對受影響的操作指引、教學與測試命令；可重用經驗依 [learning](../learning.md) 納入現有流程。

長出來才建：`landed/`（已落地功能目錄：功能在哪、實作細節指標）、`gotchas.md`（本工作流專屬踩坑）、`archive/`。

## 交接

- 改到一半發現該先整理結構 → [refactor](../refactor/README.md)。
- 為什麼選這個做法 → [decisions](../decisions.md)；卡在使用者 → [WAIT_USER](../../WAIT_USER.md)。
