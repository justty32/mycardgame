# UI 子工作流

[UI 入口](../ui.md)｜[圖像素材](../art-assets.md)｜[呈現核實](../../../../analysis/slay-the-robot/design/presentation.md)

**何時用**：已由 UI 入口定義玩家任務，需要找到實際場景、狀態、元件與測試接點。**何時不用**：只換素材回圖像；改結算規則接整局／機制流程。

## Done when

選定子流程的任務 spec（`games/<game>/design/specs/`）與驗證紀錄（`games/<game>/design/plans/`）存在，列出來源、改動、實測結果與未驗範圍；文件 strict lint 回傳 0。

## 流程與導航

完整畫面需求先讀 [場景與用途](screens/README.md)：戰鬥、對話、商店／休息、獎勵／選牌、地圖、選單／收藏各有整套玩家旅程與音畫接線。下表是共用技術子流程，不能取代完整場景規格。

<!-- wf-nav -->
| 任務 | 子流程 |
|---|---|
| HUD、卡牌可用性、敵人目標、tooltip、modal、獎勵／選牌、確認取消與新輸入方式 | [互動與狀態](interaction-states.md) |
| 共用 theme／components、HUD 層級、容器、長文字、無障礙與 viewport 規格 | [元件與版面](components-layout.md) |
| 主選單／結算改版、繁中、字型與尺寸 | [選單、文字與尺寸](menus-localization.md) |
| 背景 fixture 接入、HUD／modal 斷言、既有套件範圍與待驗證據 | [UI 專項驗證](verification.md) |

先沿實際資料與控制流程選前兩篇，需要主選單／結算才加第三篇；最後由專項驗證定義證據。沒有 UI 需求規格時，按 UI 入口先提出最小方案並分出核心規則未決。

## 交接

共同規則在 UI 入口；靜態來源事實在呈現分析。桌面／視窗／真實焦點／截圖限制持續適用，背景結果不能替代視覺、實際輸入或手把可玩性。
