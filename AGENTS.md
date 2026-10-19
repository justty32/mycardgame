# mycardgame — AI agent 專案備忘

mycardgame = **以 Slay-The-Robot 為框架的個人卡牌遊戲開發基地**：根目錄是題材中立的框架——遊戲原始碼在 [game/project.godot](game/project.godot)，工作流在 wf/，核實分析在 [analysis](analysis/slay-the-robot/README.md)；各款遊戲在 [games](games/README.md)（每款一棵題材樹：AGENTS 入口、design、wf overlay、內容包）。背景與來源見 [PROJECT.md](wf/PROJECT.md)；分層原則見 [STRUCTURE.md](wf/STRUCTURE.md)。

## 開場與入口

- 每個 session 先跑 `rg -c '^- \[' wf/SESSION-LOG.md wf/WAIT_USER.md`：有條目才開 [SESSION-LOG.md](wf/SESSION-LOG.md)（進度）/ [WAIT_USER.md](wf/WAIT_USER.md)（等使用者）；無匹配的 exit 1 表示沒有 open 項目。
- 做某款遊戲的題材工作（玩法設計、內容包、題材 probe）→ 再讀該遊戲的 `games/<game>/AGENTS.md`；題材名詞與參考來源只寫在該題材樹。
- 新 agent 接手或多人協作 → [agent-session](wf/workflows/agent-session.md)；遊戲修改 → [game-dev](wf/workflows/game-dev/README.md)。
- **碰原始碼前**：慣例與 code map → [workflows/common/conventions.md](wf/workflows/common/conventions.md)、[workflows/common/code-map.md](wf/workflows/common/code-map.md)；環境與指令 → [workflows/dev-env.md](wf/workflows/dev-env.md)。
<!-- wf-insert:AGENTS -->
- **要你動手做事** → [WORKFLOWS.md](wf/WORKFLOWS.md) 依意圖派發，再讀該工作流入口檔。
- **想看專案結構** → [INDEX.md](wf/INDEX.md)。
- 使用者偏好與邊界 → [workflows/common/user.md](wf/workflows/common/user.md)。

## 鐵律（always-on，隨時適用）

1. 重構 / 整理**不改原意**：文件驗證為 `bash wf/tools/wf-lint.sh --strict .` 加框架／題材邊界 `python3 tools/boundary_lint.py`，遊戲背景驗證用 `python3 tools/test_game.py --suite Smoke`（Windows 可用 ps1 包裝）；適用範圍與已知限制見 [testing](wf/workflows/testing.md)。其他工作照 `Done when:` 驗收。
2. **不可逆或對外的動作**（push、刪除、對外送出、動 DB）要有**授權來源**：使用者當場確認，或他親自登記在清單裡（routines / schedule）。都沒有就先問。
3. **條列走資料檔、導航留 md**：給 AI 消化的表／清單 >1 KB 存 `.json`／`.csv`（契約 `wf-table/1`，見 [data-files](wf/workflows/common/data-files.md)），用 `wf/tools/tabledb.py` 讀寫、不整份讀進 context；給人點的導航連結留 md。
4. **具體流程**在各工作流入口檔，不在頂層。
5. **程式與工作流一起維護**：agent 交付前同步受影響的分析與操作流程；可重複經驗依 [learning](wf/workflows/learning.md) 自行整理，不只留在對話。

<!-- wf-kernel v0.6 (2026-09-02) -->
