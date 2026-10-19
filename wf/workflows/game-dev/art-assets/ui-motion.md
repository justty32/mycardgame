# UI 動態 — 卡牌、回合、選角、選單與結算

[素材入口](README.md)｜[整組場景包](../scene-pack.md)｜[場景編排](scene-choreography.md)｜[人物逐格](animation.md)

**何時用**：依完整用途交付動態、素材、事件、輸入及音訊接線。**何時不用**：只改布局／互動走 [UI 畫面入口](../ui/screens/README.md)，只換圖走素材入口。

## Done when

用途記錄填有事件→資料ID→視覺根→素材→時間段→輸入／取消／還原→驗收；新實作有檔案與專項日誌，僅規劃明標未實作，文件 lint 通過。未驗畫面不可寫成完整演出通過。

## 流程

先讀 [共通契約](motion/README.md)，固定單一 owner、generation、跳過／取消及減少動態；再依用途選以下文件。

<!-- wf-nav -->
| 用途 | 操作與實碼 |
|---|---|
| 抽牌、hover、選目標、出牌、棄牌、升級 | [卡牌動態](motion/cards.md) |
| 回合提示、選角、選單、結算 | [畫面轉場](motion/menus.md) |

現況不是所有UI都有動畫：手牌Pivot有0.2秒Tween，hover直接改位置；Card內的hover動畫尚無play呼叫。BaseMenu只有預設null的轉場hooks，選角及結算多為立即更新。每個子流程區分既有、待實作與未驗，不以存在動畫節點代替消費端證據。

## 交接

交美術素材分層／尺寸，交UI視覺根與輸入／還原政策，交音訊唯一cue事件。下一步選一個用途建候選與helper，再實作控制器；來源與限制見 [動畫分析](../../../../analysis/slay-the-robot/design/animation.md)。當前僅文件／背景靜態，不執行Godot、GUI、聲音或製作素材。
