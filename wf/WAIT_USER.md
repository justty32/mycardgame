# WAIT_USER — 等待使用者（只列 open）

[INDEX](INDEX.md)｜我的進度另記 [SESSION-LOG](SESSION-LOG.md)

需要**使用者親自**做 / 驗證 / 決定的事：實機測試、外部服務登入、環境變數、權限、付費、需帳號的下載、去開另一個 agent。agent 做到結構性驗證的極限，跨不過的那關記這裡。

條目格式：`- [工作流] 請使用者做什麼 → 做完我接著做什麼`，做完即刪。等別的 session / agent 不記這裡（判別表見 [WORKFLOWS](WORKFLOWS.md)）。

> 膨脹就拆：堆多了就開 `wait-user/` 按類別拆檔，本檔只留一張 `| 類別 | open | 清單 |` 導航表，每列連到 `wait-user/<類別>.md`（照 [STRUCTURE](STRUCTURE.md)）。

## 待使用者項

- [testing] 回公司 Windows 機時跑 `./tools/test-game.ps1 -Suite All` 與 `python tests/test_runner_diagnostics.py`，確認 ps1 薄包裝、不開窗、taskkill 殺樹、APPDATA 隔離、.tools/godot-4.7 引擎探測（Python 3.12 以下的 junction 跳過）；另驗 `python tools/link_pack.py <pack>` 的 Windows junction 路徑（symlink 失敗退 mklink /J）與 ps1 新參數 `-Pack`／`-PackTests`／`-ContentProfile`（見 pack 流程）；All 已含新 suite Ctb（亦可 `-Suite Ctb`）→ 回報結果後我修正並更新 dev-env／testing
- [game-dev] 實機打一場戰鬥，照 combat-framework phase-1 plan 末節看 TimelineBar、TurnOverlay、End Turn 與動畫 → 回報後我修 UI
- [repo 結構] 拆 repo 時再問使用者：框架 repo 是否改名（如 cardframework）、題材樹是否各自獨立成 repo；改名前現有名稱與 `mycardgame-tests` 等執行期字串先不動 → 使用者決定後我做改名與連結修正
