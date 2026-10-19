# wf — apocalypse 題材 overlay

[apocalypse](../README.md)｜[agent 入口](../AGENTS.md)

只放本題材專屬的背景、決策、roadmap 與邊界詞表；操作流程一律引用框架的 [WORKFLOWS](../../../wf/WORKFLOWS.md)，不在這裡重寫。

<!-- wf-nav -->
| 路徑 | 內容 |
|------|------|
| [PROJECT.md](PROJECT.md) | 題材來源、參考資料（spire-codex）與發行條件 |
| [decisions.json](decisions.json) | 本題材的決策記錄（欄位同框架 [decisions](../../../wf/workflows/decisions.md)） |
| [forbidden-terms.txt](forbidden-terms.txt) | 只准出現在本題材樹的詞表（boundary lint 用） |
| [boundary.json](boundary.json) | pack id 前綴與允許刻意 patch 的框架 id |

## 決策記錄

[decisions.json](decisions.json) 依時間追加，新的在最後；欄位：`date`、`decision`、`rejected_and_why`、`premise`，意義同框架 decisions。統計：2 筆，皆 2026-10-19。

## roadmap（會做，何時）

| 事項 | 何時 / 順序 | 前提 |
|------|------------|---------|
| 定義原創玩法與最小可玩內容 | 進行中：先做概念原型（使用者 2026-10-19，見 [core-loop](../design/core-loop.md)） | 決定核心玩法，再依 game-flow 建立新局、選擇、戰鬥／非戰鬥、結算與續玩的最小閉環 |
