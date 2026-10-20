# SESSION-LOG — 進度（只列 open）

[INDEX](INDEX.md)｜等使用者的另記 [WAIT_USER](WAIT_USER.md)

**寫入時機**：
1. **開始**多步驟工作前先寫一行 open（不是做完才寫）；硬中斷時本檔才有「進行中」。
2. **每次 commit 後**更新或刪除該行。
3. 條目格式：`- [工作流] 一句 open 狀態 → 下一步 / 連結`；完成即刪，歷史交給 git log，決策落到 [workflows/decisions.md](workflows/decisions.md)。

> 膨脹就拆：過大就開 `session_logs/` 按工作流拆檔＋index（照 [STRUCTURE](STRUCTURE.md)）。

## 最新進度

- [game-dev] 豐富中性示範包未做（教學移動／推拉／範圍卡與障礙遭遇）；正常新局已接雙盤與本體站格，不等同示範內容齊備 → 內容另做後配合 WAIT_USER 實機檢查
- [dev-env] scratchpad 的 `playtest` worktree（detached c662729）是暫存，勿刪；不用後 `git worktree remove` 或目錄消失後 `git worktree prune`

## 各工作流 session-log

| 工作流 | session-log | open 摘要 |
|--------|-------------|----------|

