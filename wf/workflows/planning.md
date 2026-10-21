# planning — 想法成熟管線（idea → roadmap → 詳規 → 執行）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

從萌芽到動工的四階段收在**同一條管線**，不拆成四個工作流——免得卡在「這算 idea 還是 roadmap」。

**何時用**：使用者說「記個想法」「以後要做」「排進 roadmap」「幫我規劃」；或要「規劃遊戲／遊戲設計」、核心玩法尚未定案（走下方「遊戲規劃」）。
**何時不用**：三兩步的小事直接做；已有 spec / plan 且在動工 → 執行工作流；只是要調查清楚 → investigation（dev 包）。

## Done when

- idea / roadmap：對應表多一列，或既有列狀態欄更新。
- 詳規：spec 有「方案 / 取捨」段、plan 有「步驟 / 驗證」段，位於下方「任務規格與 plan 落點」的路徑（完成後的封存位置同節）。
- 遊戲規劃：`games/<game>/design/core-loop.md`、`games/<game>/design/content-scope.md` 的必問項已填使用者答案或仍標「待定」並說明卡在哪；取捨在該題材樹的 decisions.json 有對應列。

## 階段

| 階段 | 回答的問題 | 落點 |
|------|-----------|------|
| **idea** | 要不要做？ | 下方「想法」表 |
| **roadmap** | 會做，何時？ | 下方「roadmap」表 |
| **詳規** | 怎麼做？ | 開發：**spec**（方案）→ **plan**（動工前詳規），落點見下節。非開發：目前未導入對應流程，先在 idea／roadmap 記錄|
| **執行** | — | 遊戲：game-dev；tools／wf：feature-dev；非開發：未導入 |

## 任務規格與 plan 落點

題材級每款遊戲一個落點（`<game>` 由派工指定），框架級（題材中立的框架能力）另有 `wf/specs/`、`wf/plans/`（[decisions](decisions.md) 第 17 列）。各工作流 Done when 的「任務 spec／plan」都指這裡：

- spec（方案、取捨、設計 brief）：`games/<game>/design/specs/YYYY-MM-DD-<slug>.md`。
- plan（步驟、驗證、實際驗收記錄）：`games/<game>/design/plans/YYYY-MM-DD-<slug>.md`，與 spec 同名。
- 框架級 spec：`wf/specs/<topic>/README.md` 為入口，依 lint 大小拆成多檔（大表走資料檔）；plan：`wf/plans/<topic>/`，按階段一檔記錄實際驗收。框架 spec 不放 `games/`，題材樹只放需求與驗收一頁連回框架 spec。
- 小改不開 spec／plan（跨系統或長任務才建立）：任務記錄寫在 commit 訊息與交付回報。
- 目錄在第一份出現時建立；動工完成移 `games/<game>/design/archive/`（框架級移 `wf/specs/archive/`、`wf/plans/archive/`）。題材樹導航由根 AGENTS.md 路由。

## 遊戲規劃

核心玩法未定、或使用者要「規劃遊戲」時用。目標是把會改變核心玩法的決定問齊，**不替使用者決定遊戲內容**。

**提問**：一次問齊下列必問項，已答的不重問：

- 題材／fantasy：玩家扮演誰、在什麼世界。
- 核心差異機制：和一般爬塔卡牌最不同的一條規則。
- 角色與起始牌組：幾個可選角色、各自的起手方向。
- 幕數與局長：幾幕、一局預期幾分鐘。
- 節點種類：戰鬥／菁英／事件／商店／休息／寶箱取捨。
- 勝敗與局外成長：勝敗條件、局外保留什麼。
- 呈現／美術風格：參考作品或關鍵詞。
- 發行目標：個人／免費公開／商業；影響非商業授權的外部參考能否採用（來源與條件記在該題材樹）。

**預設**：清單外的細節（數值、卡名、UI 布局、存檔時機等）agent 自擬預設，標「預設（agent 提議，可改）」，不另開確認回合。

**記錄**：答案寫入 `games/<game>/design/core-loop.md` 與 `games/<game>/design/content-scope.md`，註明「使用者 YYYY-MM-DD」；未答保持「待定」，卡住後續工作時記 WAIT_USER 一行。有兩個以上可行方案的取捨，依 [decisions](decisions.md) 的欄位用 tabledb 追加到題材樹 `games/<game>/wf/decisions.json`（框架通用的取捨才進本 wf 的 decisions.json），`rejected_and_why`、`premise` 必填。

**開發順序**：設計可用後依 [最小可玩版本](game-dev/game-flow/vertical-slice.md) 排步驟，首份 spec／plan 放上節落點，執行接 [game-dev](game-dev/README.md)。

## 想法（要不要做）

| 想法 | 一句話 | 狀態（想想 / 會做→搬 roadmap / 不做＋原因）|
|------|--------|------------------------------------------|

## roadmap（會做，何時）

已抽到 [roadmap 資料](planning-roadmap.json)（4 列）。`item` 是事項，`order` 是順序與接手入口，`premise` 是前提；涵蓋題材最小版本、框架階段、每場盤數遷移與第二款題材。

框架已匯入、修復 Dictionary 與資源生命週期並建立流程回歸，見 [當前驗證](../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)。上述事項仍屬後續玩法方向，基準測試通過不代表原創內容已完成；落地順序見 [整體遊戲流程](game-dev/game-flow.md)。

## 交接

遊戲詳規由 agent 依目前需求維護，至少說清楚玩家可觀察的行為、影響資料／機制／UI、既有存檔影響、實作範圍與驗收證據；不為一般工程決策新增確認關卡。

執行時接 [game-dev](game-dev/README.md)；完成後將穩定操作與可重複經驗整理到 [learning](learning.md) 指定的位置，規劃筆記不取代現行工作流。

- 決定「為什麼選 A 不選 B」 → [decisions](decisions.md)。卡在使用者 → [WAIT_USER](../WAIT_USER.md) 一行；跨 session → [SESSION-LOG](../SESSION-LOG.md) 一行。
