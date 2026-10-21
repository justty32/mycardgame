# 每場戰鬥的棋盤大小

[模組契約](README.md)｜[雙盤 A](../dual-board/README.md)｜[呈現](../dual-board/presentation.md)｜[關卡：戰鬥遭遇](../../workflows/game-dev/level-design/combat.md)

2026-10-21 使用者要求每場戰鬥（encounter）都能自由調整棋盤大小；決定記錄見 [decisions.json](../../workflows/decisions.json)。本頁只管已實作的「大小」：目前掛載仍由場景旗標與規則 `board_enabled` 決定。使用者同日稍後已改定每場 0~N 盤，取代「不加每場開關」；[盤數調查](../../notes/investigations/2026-10-21-multi-board-feasibility.md) 記錄尚未實作的裝配缺口。未掛棋盤時不建立 Battlefield，也不讀、不驗這些大小欄位。

## 內容包怎麼寫

大小只寫在遭遇資料，不必改程式。寬高各自指定，雙盤可以兩盤不同；座標為 `[x, y]`，x 由 0 到寬−1、y 由 0 到高−1，y 越大越靠近玩家側（預設部署在最後兩列、生成在最前兩列）。

```json
{
  "properties": {
    "object_id": "my_encounter",
    "encounter_board_mode": 1,
    "encounter_boards": {
      "party": {"size": [3, 3], "deploy_cells": [[1, 2]]},
      "enemy": {"size": [8, 6], "blocked_cells": [[0, 5]]}
    },
    "encounter_waves": [{"wave_units": [{"weights": {"my_enemy": 1}, "board_id": "enemy", "cell": [7, 4]}]}]
  },
  "patch_data": {}
}
```

解析順序：`encounter_boards.<盤>.size` → 遭遇層 `encounter_board_size`（套用到所有盤）→ 規則 `default_board_size`（框架預設 5×5）。任一層寫 `[0, 0]` 或省略都表示沿用下一層，所以沒寫大小的舊遭遇與合成遭遇行為不變。SINGLE 模式的盤名是 `shared`。

## 上下限與理由

允許範圍由規則 `board_min_size`／`board_max_size` 決定（含端點），框架預設 3×3 到 12×12；內容包可在自己的 `combat_rules_default` 收窄或放寬，但 `board_max_size` 不能超過程式常數 `CombatRulesData.BOARD_SIZE_CEILING` 16×16，且 `default_board_size` 必須落在範圍內。

下限 3：最小仍有中心格，CROSS 與 SQUARE_3 能完整落在盤內；預設的兩列部署與兩列生成仍各有空間。原本的 5×5 下限來自 SINGLE 共用盤需要雙方之間隔一列；雙盤 A 各方一盤後不再必要。SINGLE 盤低於 5 列時預設部署與生成列會重疊，這類遭遇請明寫部署與生成格。示範包 board-lab 的規則把下限收窄為 5×5，屬於該包的選擇。

上限 12：每盤畫面槽為 460×280 px（雙盤左右並列），12 列時格寬約 23 px、角色縮放約 0.18，再大就難以點選與辨識。16 是硬上限（約 17.5 px），給刻意接受小格的內容包。尋路、威脅預覽與 AI 都按實際格數計算；上限依呈現決定，未針對效能另作量測。

## 驗證與錯誤

驗證在棋盤模組建立 Battlefield 時執行。不合法時該場不建立棋盤，`BoardController` 以 log_error 輸出代碼與說明，說明會指出遭遇 id、盤名、出錯的值與允許範圍，例如「board "party" deploy_cells [3, 2] is outside the 3x3 board (x 0..2, y 0..2)」。不再把過小的尺寸默默夾到下限，也不再靜默略過盤外的格子。

| 代碼 | 情況 |
|---|---|
| `invalid_board_size_limits` | 規則的上下限或預設大小自相矛盾、超過 16×16 |
| `invalid_encounter_board_size` | size 不是兩個整數，或只有一軸 ≤ 0 |
| `encounter_board_size_out_of_range` | size 超出規則允許範圍 |
| `encounter_cell_out_of_bounds` | 部署、生成、障礙、初始場域或波次單位格超出所在盤 |
| `invalid_encounter_board`／`invalid_encounter_wave_board` | 盤名不屬於目前模式 |

波次單位沒寫 `cell` 仍改用最近的生成區空格；寫了但在盤外則屬錯誤。作者想提早看到錯誤時，帶著內容包跑 Smoke：probe 會逐一驗證已載入的遭遇，失敗訊息直接列出上述說明。

## 呈現

[BoardView](../../../game/scripts/ui/BoardView.gd) 的 `compute_layout` 依實際大小取能放進 460×280 槽的最大正方格（上限 64 px）；[BoardCombatPresentation](../../../game/scripts/ui/BoardCombatPresentation.gd) 的 `view_position` 把每盤置中於自己的槽（雙盤左槽 x=70、右槽 x=640，單盤 x=360，y=170），角色縮放由 [BoardActorPresentation](../../../game/scripts/ui/BoardActorPresentation.gd) 的 `actor_scale_for` 依格寬計算。5×5 盤因此比改動前右移 90 px；格寬、縮放與點格換算不變。

## 證據與未驗

[board_size_cases](../../../tests/board_size_cases.gd)（Board suite）驗預設不變、3×3、8×6、不對稱雙盤、規則收窄／放寬、各類錯誤訊息與版面數值；Smoke probe 驗已載入遭遇。真正 NONE 與刪除模組檔由既有 Boardless／BoardRemoved 回歸。這些是 headless 數值與流程斷言：各尺寸的實際觀感、字級、角色遮擋與滑鼠命中都未驗，屬使用者人工驗收項。
