# game-flow — 整局流程與最小可玩版本

[遊戲開發](README.md)｜[子流程目錄](game-flow/README.md)｜[規劃](../planning.md)｜[流程核實](../../../analysis/slay-the-robot/design/game-flow.md)

將主選單、角色選擇、新局、地圖與節點、跨幕、勝敗、續玩及重開接成可驗證的一局；先決定玩家看到的流程，再分配內容、機制與 UI 工作。

**何時用**：規劃原創最小可玩版本、串接整局、變更新局／續玩／結算，或界定局內與局外進度。

**何時不用**：只改一個遭遇走 [level-design](level-design.md)；單卡走 card-design；純外觀走 [ui](ui.md)；底層序列化修正走 [mechanics](mechanics.md)。已知局部問題不必重做整局規格。

## Done when

任務規格存在，寫明採用的狀態、轉移入口、權威資料、完成／拒絕條件、存檔政策與最小內容範圍；開發順序與各步驗收可定位。實作任務另有新局至結算／再開及適用中斷恢復的測試輸出，命令回傳預期結果；只規劃時標為未實作、未執行。受影響分析同步，文件 strict lint 回傳 0。

## 流程

### 固定任務範圍

先讀 [核心接手規矩](../agent-session.md)，再依來源鎖與當前 source/tests 核實。原創題材、核心決策、永久成長尚未定案時保留待決，不把上游範例當產品需求；已能獨立完成的流程盤點繼續。需要一個可玩垂直切片時依 [最小開發順序](game-flow/vertical-slice.md) 控制範圍。

### 建立轉移契約

先列主選單／角色設定、起點、可旅行地圖、戰鬥、非戰鬥 overlay、獎勵、幕末、勝敗摘要及返回標題。這是規格中的狀態，不表示框架已有單一狀態機；實作由 Global、Map、Combat 與各 overlay 的資料及訊號共同控制。每個相關轉移寫「入口與前提 → 資料改變 → 完成訊號／目的地 → 中斷後位置」，避免僅畫連線而漏掉實作責任。

責任與 source 入口集中在 [核實筆記](../../../analysis/slay-the-robot/design/game-flow.md)：MainMenu／NewRunMenu 管開始與續玩，Global 建立／結束 run，Map 限制旅行，節點各自管理互動，RunSummary／StatsHandler 完成結算。跨域工作依這些責任分工；共用檔案仍只有一位 owner。

### 分清一般節點、幕末與終局

由 [level-design](level-design.md) 定義可達圖與合法終點，依節點種類接 [戰鬥／非戰鬥實作](../../../analysis/slay-the-robot/design/encounters.md)。框架判斷終點使用「無後繼位置」及 player_act_max，不能只改 act_next_act_ids 就假設通關成立。

非終局戰後獎勵 Continue 能轉幕；最終戰由 RunSummary 的 combat_ended handler 直接進勝利，一般獎勵不顯示。REST／EVENT 與其他節點的離開路徑不一致，沒有通用的「所有節點都自動轉幕」。如果需求改為最終 Boss 先領獎、事件作幕末或自訂結算，須指定新的責任與專項回歸，不能只改文字或資料。

### 明定保存及驗收

按 [存讀與局外進度](game-flow/persistence.md) 區分 QUIT、LOSS、VICTORY、Forfeit、重新載入與新 run。先選擇 checkpoint 或擴充存檔契約，再設計對玩家的保存承諾；按鈕名「Continue」不是恢復任意中途狀態的證據。

驗收從玩家可到達入口走到結果。直接呼叫訪問 action 可測機制，但繞過 Map 鄰接限制；直接送 run_victory 只能測摘要接線，不能證明 Boss 通關。已有 [Combat](../../../tests/combat_flow.gd)／[SaveLoad](../../../tests/save_load_flow.gd) 可作基準，新增整局分支依 [validation](validation.md) 補測，保留未驗項目。

## 交接

流程契約交 [content](content.md) 接角色／內容、level-design 接地圖／節點、mechanics 接規則／存檔、ui 接畫面／輸入。行為真相與缺口更新核實筆記；測試命令由 [testing](../testing.md) 管理，不自行宣稱已有新 suite。使用者目前禁止 UI／桌面／截圖與 GUI；背景接線證據不替代呈現和實際輸入驗收。
