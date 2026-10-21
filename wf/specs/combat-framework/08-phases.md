# 分階段實作計畫（§5）

[README](README.md)

本檔是 §5 的索引：共同驗證命令、各階段分檔、移動增補的分配與時序。各階段的改動、規模、風險、Done when 與 agent 分工寫在下表的分檔裡；與原文的偏差以「**修訂（實作 Phase N）**」段落標在該階段內，實際驗收見 [plans/combat-framework](../../plans/combat-framework/phase-3.md)（最新為 Phase 3，前一階段由檔頭連過去）。

## 共同驗證命令（每階段 Done when 都要）

- V1 `bash wf/tools/wf-lint.sh --strict .` 與 `python3 tools/boundary_lint.py`（皆 exit 0；後者確保框架目錄無題材詞與 `games/` 路徑），適用範圍見 [testing](../../workflows/testing.md)。
- V2 `python3 tests/test_runner_diagnostics.py`（全過；新增 suite 時補假引擎案例）。
- V3 `python3 tools/test_game.py --suite Smoke`；階段 1 起另跑 `--suite All`。
- V4 該階段新增的 headless 測試（接進 `tools/test_game.py` 的 suite 清單，並一併補 `test_runner_diagnostics.py` 案例）。

agent 分級依 [user.md](../../workflows/common/user.md) 現行指定（普通派 opus、簡單工作與雜活派 sonnet），各階段的 agent 段已依此改寫。所有 fixture 只用框架測試資料（`character_red`、`enemy_1`、`card_attack_basic`…），禁止題材 id 進 `game/`、`tests/`。

## 各階段

<!-- wf-nav -->
| 階段 | 可玩 | 狀態 | 檔 |
|---|---|---|---|
| Phase 0：基礎重構——combatant 抽象化、單位註冊表、規則物件 | 與現在完全相同 | 已完成 | [08a](08a-phase-0.md) |
| Phase 1：CTB + 單一主角 | 一名主角 vs 多敵，依速度排隊 | 已完成 | [08b](08b-phase-1.md) |
| Phase 2：棋盤 + 移動 + 範圍／形狀卡 | 主角在 5×5 移動並用射程卡 | 已完成；後由雙盤 A 與可選模組延伸，見 [README](README.md#方向更新雙盤-a-與可選棋盤模組取代-g4-原文) | [08c](08c-phase-2.md)、Done when [08d](08d-phase-2-done-when.md) |
| Phase 3：波次 | 一場遭遇兩波 | 已完成 | [08e](08e-phase-3-2b.md#phase-3波次) |
| Phase 2b：場域格與控制區（移動增補，排在 Phase 3 之後） | 戰鬥中場域與控制區可觸發 | 已完成（9ced42f，suite `Field`） | [08e](08e-phase-3-2b.md#phase-2b場域格與控制區) |
| Phase 4：多主角資料模型 + AI 隊員戰鬥行動 | 主角 + 2 名 AI 隊員 | 未動工 | [08f](08f-phase-4-6.md#phase-4多主角資料模型--ai-隊員戰鬥行動) |
| Phase 5：招募／培養／AI 選牌獎與購卡／升階 | 局中招募、戰後各自選牌 | 未動工 | [08f](08f-phase-4-6.md#phase-5招募培養ai-選牌獎與購卡升階) |
| Phase 6：存檔版本拒絕與收尾 | 舊存檔被拒絕並提示；proxy 清除 | 未動工 | [08f](08f-phase-4-6.md#phase-6存檔版本拒絕與收尾) |

## 移動增補的階段分配（原移動草案 §9）

移動規則增補（[11](11-movement-active.md)–[15](15-movement-cards.md)）的「Phase 2 增補」已併入 [Phase 2](08c-phase-2.md) 的改動、規模、風險與 Done when（以「移動增補」標示）；新增的 Phase 2b 寫在 [08e](08e-phase-3-2b.md#phase-2b場域格與控制區)，排在 Phase 3（波次）之後、Phase 4（AI 隊員）之前；「題材包補列」已併入 [10-pack-requirements.md](10-pack-requirements.md) 的 [pack-requirements.json](pack-requirements.json)。

各移動項目屬 Phase 2 或之後的分配表已抽到 [movement-phasing.json](movement-phasing.json)（8 列）。欄位：項目（對應移動草案節號）、Phase 2（棋盤）（✔＝Phase 2 做）、之後（延到哪個階段）。

## 時序與協作

Phase 0 只加不刪；新 suite 改 `tools/test_game.py` 時一併補 `test_runner_diagnostics.py` 案例。每階段開工時在 `wf/plans/combat-framework/` 開同名 plan 記錄實際驗收；階段間可並行的只有「資料欄位 + 測試資料」雜活。
