# level-design — 遭遇、非戰鬥節點與幕設計

[遊戲開發](README.md)｜[子流程目錄](level-design/README.md)｜[內容接線](content.md)｜[全局流程](game-flow.md)｜[核實來源](../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：建立或評量戰鬥遭遇、選項事件、商店／休息／寶箱、路線及 act 節奏。**何時不用**：單體敵人走 [enemy-design](enemy-design.md)，新規則走 [mechanics](mechanics.md)，純地圖外觀走 [UI](ui.md)；題材尚未決定時先保留設計方案。

## Done when

任務設計與接線檔存在，列明本次內容 ID、玩家入口、成本／收益、通過門檻及存讀政策。對應子流程的專項斷言和日誌存在，實際執行命令回傳預期結果；純設計或未執行部分明列。受影響分析同步，文件 strict lint 回傳 0。既有 Smoke／Combat 通過不能代替新增遭遇或完整章節驗收。

## 流程

先讀 [agent-session](../agent-session.md) 核心規矩與來源版本；按本次責任選下列一條最短路徑，跨領域再接另一條，不必先讀整個遊戲原始碼。

<!-- wf-nav -->
| 要完成的工作 | 操作入口 |
|---|---|
| 一場普通戰鬥、精英或 Boss 的敵群與池接線 | [戰鬥遭遇](level-design/combat.md) |
| 選擇／代價／獎勵事件，或 shop/rest/treasure | [非戰鬥事件與設施](level-design/noncombat.md) |
| 分支地圖、生成約束、資源節奏與幕切換 | [地圖與幕](level-design/map-act.md) |

開始前寫下玩家在何時、以何種牌組／生命／金錢面對什麼決策，以及完成後回到哪個流程。機制不能表達的需求先明列，交 mechanics 以失敗測例修復；不把設計 budget、難度目標或任意 JSON 欄位當引擎能力。

## 交接

交付設計、ID／修改點、專項測例、seed／策略／樣本、日誌與未驗部分。單體調整回 enemy-design，載入與 mod 回 content，全局開始／續玩／結算回 game-flow。大量同質評量依 [資料契約](../common/data-files.md) 存資料檔；驗證方式見 [validation](validation.md)。只做目前授權的背景檢查，視窗呈現、點擊命中與視聽節奏仍須獨立證據。
