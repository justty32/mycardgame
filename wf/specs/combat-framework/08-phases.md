# 分階段實作計畫

[README](README.md)

## 5. 分階段實作計畫

共同驗證命令（每階段 Done when 都要）：
- V1 `bash wf/tools/wf-lint.sh --strict .` 與 `python3 tools/boundary_lint.py`（皆 exit 0；後者是分離遷移新加的鐵律，確保框架目錄無題材詞與 `games/` 路徑）
- V2 `python3 tests/test_runner_diagnostics.py`（全過；新增 suite 時補假引擎案例）
- V3 `python3 tools/test_game.py --suite Smoke`；階段 1 起另跑 `--suite All`
- V4 該階段新增的 headless 測試（接進 `tools/test_game.py` 的 suite 清單；在另一 agent 的 runner 改動 commit 後再動 runner，避免衝突）

agent 分級依 [user.md](../../workflows/common/user.md) 現行指定（普通派 opus、簡單工作與雜活派 sonnet）；phases.json 的 agent 欄已依此改寫。所有 fixture 只用框架測試資料（`character_red`、`enemy_1`、`card_attack_basic`…），禁止題材 id 進 `game/`、`tests/`。

各階段的改動、規模、風險、Done when、agent 已抽到 [phases.json](phases.json)（8 列，每列一個階段；含 2b）。欄位：phase、title、playable、changes、size、risk、done_when、agent。下列標題只列階段名稱與可玩狀態。

### Phase 0：基礎重構——combatant 抽象化、單位註冊表、規則物件（可玩：與現在完全相同；**已完成**）


### Phase 1：CTB + 單一主角（可玩：一名主角 vs 多敵，依速度排隊；**已完成**）


### Phase 2：棋盤 + 移動 + 範圍／形狀卡（可玩：主角在 5×5 移動並用射程卡；**已完成**；後由雙盤 A 與可選模組延伸，見 [README](README.md#方向更新雙盤-a-與可選棋盤模組取代-g4-原文)）


### Phase 2b：場域格與控制區（可玩：戰鬥中場域與控制區可觸發；移動增補，見 [16-movement-phasing.md](16-movement-phasing.md)，排在 Phase 3 之後；**已完成**，9ced42f，suite `Field`）


### Phase 3：波次（可玩：一場遭遇兩波；**已完成**）


### Phase 4：多主角資料模型 + AI 隊員戰鬥行動（可玩：主角 + 2 名 AI 隊員）


### Phase 5：招募／培養／AI 選牌獎與購卡／升階（可玩：局中招募、戰後各自選牌）


### Phase 6：存檔版本拒絕與收尾（可玩：舊存檔被拒絕並提示；proxy 清除）


### 時序與協作

Phase 0 可立即開工（只加不刪）；Phase 1 開工前等分離遷移的 runner／smoke 改動 commit，之後新 suite 改 `tools/test_game.py` 時一併補 `test_runner_diagnostics.py` 案例。每階段一個 plan 檔記錄實際驗收；階段間可並行的只有「資料欄位 + 測試資料」雜活。
