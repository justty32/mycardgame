# INDEX — mycardgame 專案地圖

mycardgame 是以 Slay-The-Robot 為框架的個人卡牌遊戲開發基地：根目錄為題材中立的框架，已完成工作流、框架原始碼引入與啟動基準核實；各款遊戲另放題材樹。

## 專案入口

| 路徑 | 內容 |
|------|------|
| [AGENTS.md](../AGENTS.md) | agent 入口與共通規則 |
| [CLAUDE.md](../CLAUDE.md) | Claude 的入口轉址 |
| [PROJECT.md](PROJECT.md) | 範圍、上游角色、內建教學與導入來源 |
| [game/project.godot](../game/project.godot) | 遊戲入口；檔內標記 4.7，執行基準為 Godot 4.7.x |
| [tools/test_game.py](../tools/test_game.py) | 跨平台隔離回歸、戰鬥勝敗與跨程序存讀（主 runner） |
| [tools/test-game.ps1](../tools/test-game.ps1) | 上列 runner 的 Windows 薄包裝 |
| [tools/game.ps1](../tools/game.ps1) | Windows 專用舊入口：啟動、匯入與 smoke |
| [tests/framework_smoke.gd](../tests/framework_smoke.gd) | 主場景與擴充邊界驗證 |
| [analysis/slay-the-robot](../analysis/slay-the-robot/README.md) | 本專案維護的框架分析與教學 |
| `games/<game>/` | 題材樹：各遊戲的 AGENTS 入口、design（核心玩法、內容範圍、任務 spec／plan）、wf overlay 與內容包；由根 AGENTS.md 路由，框架文件不連入 |
| [specs/combat-framework](specs/combat-framework/README.md) | 框架級 spec：隊伍制 CTB 戰棋戰鬥框架（草案；Phase 0–3 已實作） |
| [plans/combat-framework](plans/combat-framework/phase-3.md) | 上列 spec 各階段的實際驗收（Phase 0–3；最新為 Phase 3，前一階段由檔頭連過去） |
| [WORKFLOWS.md](WORKFLOWS.md) | 意圖對應工作流 |
| [agent-session](workflows/agent-session.md) | agent 冷啟動、分工與交接 |
| [game-dev](workflows/game-dev/README.md) | 整局、關卡、卡牌／敵人，以及完整場景的美術／動畫／特效／聲音／UI、第一個 mod 與驗收 |
| [learning](workflows/learning.md) | 將已驗證經驗整理成操作流程 |
| [版本控制](workflows/version-control.md) | justty32 提交／推送、snapshot 與可攜證據 |
| [workflows/common](workflows/common/README.md) | 使用者偏好、code map 與慣例 |
| [STRUCTURE.md](STRUCTURE.md) | 工作流分層與整理規則 |
| [SESSION-LOG.md](SESSION-LOG.md) | 進行中的工作 |
| [WAIT_USER.md](WAIT_USER.md) | 需要使用者親自處理的項目 |
| [驗證](workflows/testing.md) | wf/tools/ 工具與執行方式 |
| [.claude/commands/wf-lint.md](../.claude/commands/wf-lint.md) | Claude slash 指令適配層 |

上游版本與來源見 PROJECT.md；本機可攜引擎放 .tools/，可重建測試輸出放 artifacts/。
<!-- wf-insert:INDEX -->
