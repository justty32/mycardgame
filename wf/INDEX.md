# INDEX — mycardgame 專案地圖

mycardgame 是以 Slay-The-Robot 為框架、spire-codex 為參考的個人卡牌遊戲，已完成工作流、框架原始碼引入與啟動基準核實。

## 專案入口

| 路徑 | 內容 |
|------|------|
| [AGENTS.md](../AGENTS.md) | agent 入口與共通規則 |
| [CLAUDE.md](../CLAUDE.md) | Claude 的入口轉址 |
| [PROJECT.md](PROJECT.md) | 範圍、上游角色、內建教學與導入來源 |
| [game/project.godot](../game/project.godot) | 遊戲入口，Godot 4.6 |
| [tools/game.ps1](../tools/game.ps1) | 啟動、資源匯入與 smoke 指令 |
| [tools/test-game.ps1](../tools/test-game.ps1) | 隔離回歸、戰鬥勝敗與跨程序存讀 |
| [tests/framework_smoke.gd](../tests/framework_smoke.gd) | 主場景與擴充邊界驗證 |
| [analysis/slay-the-robot](../analysis/slay-the-robot/README.md) | 本專案維護的框架分析與教學 |
| [WORKFLOWS.md](WORKFLOWS.md) | 意圖對應工作流 |
| [agent-session](workflows/agent-session.md) | agent 冷啟動、分工與交接 |
| [game-dev](workflows/game-dev/README.md) | 整局、關卡、卡牌／敵人，以及完整場景的美術／動畫／特效／聲音／UI、第一個 mod 與驗收 |
| [learning](workflows/learning.md) | 將已驗證經驗整理成操作流程 |
| [版本控制](workflows/version-control.md) | WSL justty32 提交／推送、snapshot 與可攜證據 |
| [workflows/common](workflows/common/README.md) | 使用者偏好、code map 與慣例 |
| [STRUCTURE.md](STRUCTURE.md) | 工作流分層與整理規則 |
| [SESSION-LOG.md](SESSION-LOG.md) | 進行中的工作 |
| [WAIT_USER.md](WAIT_USER.md) | 需要使用者親自處理的項目 |
| [驗證](workflows/testing.md) | wf/tools/ 工具與執行方式 |
| [.claude/commands/wf-lint.md](../.claude/commands/wf-lint.md) | Claude slash 指令適配層 |

上游版本與來源見 PROJECT.md；本機可攜引擎放 .tools/，可重建測試輸出放 artifacts/。
<!-- wf-insert:INDEX -->
