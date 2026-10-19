# WAIT_USER — 等待使用者（只列 open）

[INDEX](INDEX.md)｜我的進度另記 [SESSION-LOG](SESSION-LOG.md)

需要**使用者親自**做 / 驗證 / 決定的事：實機測試、外部服務登入、環境變數、權限、付費、需帳號的下載、去開另一個 agent。agent 做到結構性驗證的極限，跨不過的那關記這裡。

條目格式：`- [工作流] 請使用者做什麼 → 做完我接著做什麼`，做完即刪。等別的 session / agent 不記這裡（判別表見 [WORKFLOWS](WORKFLOWS.md)）。

> 膨脹就拆：堆多了就開 `wait-user/` 按類別拆檔，本檔只留一張 `| 類別 | open | 清單 |` 導航表，每列連到 `wait-user/<類別>.md`（照 [STRUCTURE](STRUCTURE.md)）。

## 待使用者項

- [testing] 回 Windows 機跑 `./tools/test-game.ps1 -Suite All`（已含 Ctb、Board、Wave）與 `python tests/test_runner_diagnostics.py`，驗 ps1 不開窗、taskkill 殺樹、APPDATA 隔離、.tools/godot-4.7 探測（Python 3.12 以下跳過 junction 項），及 `link_pack.py` 的 mklink /J 退路與 `-Pack`／`-PackTests`／`-ContentProfile`（見 [pack](workflows/game-dev/content/pack.md)）→ 回報後我修正 dev-env／testing
- [game-dev] 實機打一場戰鬥，照 [合併清單](plans/combat-framework/phase-3.md#需使用者實機檢查headless-無法驗) 第 1–6 項回報 UI 觀感 → 我修 UI
- [game-dev] 決定戰鬥者圖像是否站在棋盤格上跟著移動（建議要；清單第 7 項）→ 我改 BoardView
- [repo 結構] 拆 repo 時決定框架是否改名、題材樹是否獨立成 repo（改名前 `mycardgame-tests` 等字串不動）→ 我改名修連結
