# design — apocalypse 遊戲設計

[專案地圖](../../../wf/INDEX.md)｜[規劃流程](../../../wf/workflows/planning.md#遊戲規劃)｜[開發順序](../../../wf/workflows/game-dev/game-flow/vertical-slice.md)

本資料夾記**這款遊戲要做成什麼**：使用者確認的玩法、內容範圍與任務詳規。它不同於 analysis/（Slay-The-Robot 框架的已核實事實）與 wf/（agent 的操作流程）；設計文件不寫框架行為，也不寫操作步驟。

**狀態**：核心設計部分確認（使用者 2026-10-19：天啟預報免費同人、先做概念原型），其餘欄位仍為「待定」。agent 依 [遊戲規劃](../../../wf/workflows/planning.md#遊戲規劃) 提問後填寫；未確認的值不得當成已定玩法實作。

## 文件

<!-- wf-nav -->
| 檔案 | 內容 |
|------|------|
| [core-loop.md](core-loop.md) | 題材、核心差異機制、一局流程、勝敗、局外成長、呈現方向與發行目標 |
| [content-scope.md](content-scope.md) | 角色與起始牌組、最小切片的內容數量、節點案例與暫不做的範圍 |
| [concept/concept-overview.md](concept/concept-overview.md) | 概念原型目錄（概念草案，數值為佔位）：總覽與使用者已定事項，分檔含[戰鬥 CTB／棋盤](concept/concept-battle.md)、[隊伍](concept/concept-party.md)、[核心系統](concept/concept-systems.md)、[遺物藥物與切片](concept/concept-items-slice.md)、[原型角色](concept/concept-characters.md)、[原型敵人](concept/concept-enemies.md)、[移動](concept/concept-movement.md)；卡表／清單在同資料夾 json |
| `specs/` | 任務 spec：方案與取捨，一任務一檔 `YYYY-MM-DD-<slug>.md`，第一份出現時建立 |
| `plans/` | 任務 plan：步驟、驗證與實際驗收記錄，一任務一檔，檔名同 spec |
| `archive/` | 動工完成的 spec／plan 移此凍結，規則見 [STRUCTURE](../../../wf/STRUCTURE.md#archive-規則) |

## 填寫規則

- 每個決定註明來源：「使用者 YYYY-MM-DD」或「預設（agent 提議，可改）」；尚未決定寫「待定」。
- 「為什麼選 A 不選 B」記到本題材的 [decisions](../wf/decisions.json)（欄位見框架 [decisions](../../../wf/workflows/decisions.md)），本資料夾只留結論。
- 核心設計改變時，同步檢查 `specs/`、`plans/` 中仍在進行的任務。
