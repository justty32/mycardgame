# WORKFLOWS — 工作流派發器

[INDEX](INDEX.md)｜結構 [STRUCTURE](STRUCTURE.md)

使用者要做事 → **從派發表選工作流 → 讀它的入口檔**；細節都在入口檔。

**可以跳流程**：單行或小範圍、低風險、不跨 session 的修正；純查詢或一次性回答，不留 durable 知識；使用者明確要求快速處理；既有工作流只會增加同步成本而不降低風險。跳流程不等於跳過工程規矩——仍要讀必要上下文、不破壞使用者改動、能測就測。

## 派發表

### 本專案優先入口

| 需求 | 入口 |
|---|---|
| 新 agent 接手、冷接手演練、拆任務、多 agent 協作與交接 | [agent-session](workflows/agent-session.md) |
| 整體遊戲流程、關卡／卡牌／敵人，以及完整場景的美術／動畫／特效／音訊／UI | [game-dev](workflows/game-dev/README.md) |
| 把可重複經驗變成工作流、更新開發慣例 | [learning](workflows/learning.md) |
| commit／push、snapshot、來源補丁與發布證據 | [版本控制](workflows/version-control.md) |

遊戲需求（含修遊戲 bug）一律走 game-dev，其流程節已含共同迴圈；下方 feature-dev 只用於 tools／wf 類非遊戲工作。不必逐篇讀取全部工作流。

### 開發 flavor

碰原始碼的工作流共用 [common/conventions](workflows/common/conventions.md)（寫碼慣例）與 [common/code-map](workflows/common/code-map.md)（哪個檔負責什麼）。

| 觸發（你說…）| 工作流 | 入口檔（先讀這個）|
|--------------|--------|-------------------|
| 「開發 / 修改 tools／wf 的功能」「修 tools／wf 的 bug」（遊戲的走 game-dev） | **feature-dev** | [workflows/feature-dev/README.md](workflows/feature-dev/README.md) |
| 「跑測試 / 驗證」「這樣改有沒有壞」 | **testing** | [workflows/testing.md](workflows/testing.md) |
| 「重構 / 拆檔 / 整理結構」（行為不變）| **refactor** | [workflows/refactor/README.md](workflows/refactor/README.md) |
| 「搬檔案 / 改目錄名 / 拆 repo」 | **refactor**（搬移專章）| [workflows/refactor/moving-things.md](workflows/refactor/moving-things.md) |
| 「這個陌生專案是怎麼運作的」「幫我分析這個 repo」 | **analysis** | [workflows/analysis.md](workflows/analysis.md) |
| 「查清楚這是怎麼運作的」「這樣做可不可行」 | **investigation** | [workflows/investigation.md](workflows/investigation.md) |
| 「做一包 patch 給別的專案 / 別的 agent 套」 | **patch** | [workflows/patch.md](workflows/patch.md) |
| 「環境怎麼裝」「fresh clone 後要做什麼」「指令是什麼」 | **dev-env** | [workflows/dev-env.md](workflows/dev-env.md) |

**analysis** ＝初次接觸陌生專案、要建立可延續的分析產物；**investigation** ＝回答一個窄問題。**patch** ＝跨 repo、原專案無 git 或不能直接 push、要交給冷啟動 agent 套用時才用；同一個 repo 內能改能測就走 game-dev（遊戲）或 feature-dev（tools／wf）。
<!-- wf-insert:WORKFLOWS -->

### kernel 內建

| 觸發（你說…）| 工作流 | 入口檔 |
|--------------|--------|--------|
| 「記 / 查踩坑」 | **gotchas** | [workflows/common/gotchas.md](workflows/common/gotchas.md) |
| 「整理 X」「封存過時的」「檔案太多／太雜」「太大要拆」 | **tidy** | [workflows/tidy/README.md](workflows/tidy/README.md) |
| 「記個想法」「以後要做」「排進 roadmap」「幫我規劃」「討論方案」「寫動工計畫」（spec / plan）「規劃遊戲／遊戲設計」 | **planning**（kernel 管線；遊戲內容再接 game-dev） | [workflows/planning.md](workflows/planning.md)、[game-dev](workflows/game-dev/README.md) |
| 「記個決定」「為什麼選 A 不選 B」 | **decisions** | [workflows/decisions.md](workflows/decisions.md) |
| 「我的偏好是…」「以後直接做 / 先問」 | **user** | [workflows/common/user.md](workflows/common/user.md) |

**都不符 → 看 [INDEX.md](INDEX.md)**。新開工作流 → 複製 [workflows/TEMPLATE.workflow.md](workflows/TEMPLATE.workflow.md) 並在上表加一列。原生多 agent 依 agent-session；只有實際需要持續信箱／跨工具排程時，才評估額外 flavor。

## 活狀態記哪裡（只列 open，完成即刪）

| 在等誰 | 記哪裡 |
|--------|--------|
| 等**使用者**做 / 驗證 / 決定 | [WAIT_USER.md](WAIT_USER.md) |
| 等**另一個 session / fork / agent** | [SESSION-LOG.md](SESSION-LOG.md) 一行 open（跨資料夾信件軸未導入） |
