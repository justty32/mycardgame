# game-flow — 整局流程與最小可玩版本

[遊戲開發](README.md)｜[規劃](../planning.md)｜[流程核實](../../../analysis/slay-the-robot/design/game-flow.md)

將主選單、角色選擇、新局、地圖與節點、跨幕、勝敗、續玩及重開接成可驗證的一局；先決定玩家看到的流程，再分配內容、機制與 UI 工作。

**何時用**：規劃原創最小可玩版本、串接整局、變更新局／續玩／結算，或界定局內與局外進度。

**何時不用**：只改一個遭遇走 [level-design](level-design.md)；單卡走 card-design；純外觀走 [ui](ui.md)；底層序列化修正走 [mechanics](mechanics.md)。已知局部問題不必重做整局規格。

## Done when

任務 spec（`games/<game>/design/specs/`）存在，寫明採用的狀態、轉移入口、權威資料、完成／拒絕條件、存檔政策與最小內容範圍；開發順序與各步驗收寫在對應 plan（`games/<game>/design/plans/`）。實作任務另有新局至結算／再開及適用中斷恢復的測試輸出，命令回傳預期結果；只規劃時標為未實作、未執行。受影響分析同步，文件 lint 通過（見 [testing](../testing.md#文件檢查修改後必跑)）。

## 子流程

先在本入口定義玩家旅程與狀態責任，再落到開發順序或持久化政策；這些流程支援原創版本規劃，不替使用者決定題材或玩法。單一節點內容交關卡流程，整個 run 的出口與存讀邊界由本層共同核對。

<!-- wf-nav -->
| 子流程 | 負責範圍 |
|---|---|
| [最小可玩版本](game-flow/vertical-slice.md) | 從產品契約、起局與最少內容到結算、再開的開發順序 |
| [存讀與局外進度](game-flow/persistence.md) | checkpoint、續玩、退出／放棄、結算與 profile 的政策和驗收 |

## 流程

### 固定任務範圍

先讀 [核心接手規矩](../agent-session.md)，再依來源鎖與當前 source/tests 核實。原創題材、核心決策、永久成長尚未定案時保留待決，不把上游範例當產品需求；已能獨立完成的流程盤點繼續。

### 建立轉移契約

先列主選單／角色設定、起點、可旅行地圖、戰鬥、非戰鬥 overlay、獎勵、幕末、勝敗摘要及返回標題。框架沒有單一狀態機，各狀態的責任與 source 入口見[核實筆記](../../../analysis/slay-the-robot/design/game-flow.md)；每個相關轉移寫「入口與前提 → 資料改變 → 完成訊號／目的地 → 中斷後位置」，避免僅畫連線而漏掉實作責任。跨域工作依這些責任分工，共用檔案仍只有一位 owner。

### 分清一般節點、幕末與終局

由 [level-design](level-design.md) 定義可達圖與合法終點；終點判斷及各節點的離開／轉幕出口見 [地圖與幕](level-design/map-act.md#指定跨幕終局與保存邊界)，沒有通用的「所有節點都自動轉幕」。需求若改為最終 Boss 先領獎、事件作幕末或自訂結算，須指定新的責任與專項回歸，不能只改文字或資料。

### 明定保存及驗收

保存承諾與 QUIT／LOSS／VICTORY／Forfeit 的區分走 [存讀與局外進度](game-flow/persistence.md)；按鈕名「Continue」不是恢復任意中途狀態的證據。

驗收從玩家可到達入口走到結果。直接呼叫訪問 action 會繞過 Map 鄰接限制；直接送 run_victory 只能測摘要接線，不能證明 Boss 通關。已有 [Combat](../../../tests/combat_flow.gd)／[SaveLoad](../../../tests/save_load_flow.gd) 只作基準，新增整局分支依 [validation](validation.md) 補測，保留未驗項目。

## 交接

流程契約交 [content](content.md) 接角色／內容、level-design 接地圖／節點、mechanics 接規則／存檔、ui 接畫面／輸入。行為真相與缺口更新核實筆記；測試命令由 [testing](../testing.md) 管理，不自行宣稱已有新 suite。背景接線證據不替代呈現和實際輸入驗收；需要 GUI 的部分未執行時明列。
