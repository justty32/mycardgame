# 設計與呈現能力核實

[分析入口](../README.md)｜[遊戲開發工作流](../../../wf/workflows/game-dev/README.md)

這組筆記記錄固定框架的實際資料格式、呼叫路徑與能力缺口，供未來 agent 設計遊戲時查核。基準為上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本專案修復；各篇另列實際查核日期與來源。框架或補丁變動後，要沿受影響的程式重新核對。

## 依問題選來源

<!-- wf-nav -->
| 領域 | 核實筆記 | 操作流程 |
|---|---|---|
| 卡牌、升級、卡包與評量邊界 | [卡牌](cards.md) | [設計](../../../wf/workflows/game-dev/card-design.md)、[評量](../../../wf/workflows/game-dev/card-evaluation.md) |
| 敵人意圖、遭遇、事件池與地圖 | [敵人及關卡](encounters.md) | [敵人](../../../wf/workflows/game-dev/enemy-design.md)、[關卡](../../../wf/workflows/game-dev/level-design.md) |
| 對話選項、商店、休息與寶箱 | [非戰鬥節點](noncombat.md) | [關卡子流程](../../../wf/workflows/game-dev/level-design.md) |
| 新局、跨幕、勝敗、續玩與局外進度 | [整局流程](game-flow.md) | [整局開發](../../../wf/workflows/game-dev/game-flow.md) |
| 第一個 mod、候選副本與專項測試接線 | [Mod 起步](mod-bootstrap.md) | [內容開發](../../../wf/workflows/game-dev/content.md) |
| 美術方向、批次資產、母稿與輸出 | [美術製作](art-production.md) | [美術子流程](../../../wf/workflows/game-dev/art-assets.md) |
| 角色動畫、狀態與播放／等待 | [動畫](animation.md) | [動畫製作與接線](../../../wf/workflows/game-dev/art-assets/animation.md) |
| 戰鬥視覺效果、掛點與回收 | [特效](vfx.md) | [VFX](../../../wf/workflows/game-dev/art-assets/vfx.md) |
| UI 元件、版面、狀態與輸入 | [呈現](presentation.md) | [UI 子流程](../../../wf/workflows/game-dev/ui.md) |
| 聲音載入、播放、bus 與設定 | [音訊](audio.md) | [聲音](../../../wf/workflows/game-dev/audio.md) |

雙棋盤 A、跨盤位置與人物站格見 [雙棋盤分析](dual-board/README.md)。

場景掛載與普通卡邊界見 [可選棋盤模組](board-module.md)；完整中性短流程見 [棋盤示範包](../../../examples/board-lab/README.md)。

## 如何採用

核實筆記保存程式事實與證據；工作流保存任務輸入、操作步驟與驗收。兩者均區分靜態查核、已執行測試及尚未驗證的建議。新設計若依賴已知缺口，先建立能辨認該缺口的測例並安排修復，不能把註解、資料欄位存在或固定戰鬥測試當成完整能力證明。

這些筆記沒有替本遊戲決定題材、內容或平衡數值；也沒有建立自動玩家、批次平衡器或 MCP。實際需求出現時，從領域工作流選最小必要實作，將測試與設計評量結果回寫對應來源，保持一份可追溯的現行知識。
