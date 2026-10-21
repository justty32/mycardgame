# 每場戰鬥的棋盤大小

[模組契約](README.md)｜[雙盤 A](../dual-board/README.md)｜[呈現](../dual-board/presentation.md)｜[關卡：戰鬥遭遇](../../workflows/game-dev/level-design/combat.md)

2026-10-21 使用者要求每場戰鬥（encounter）可調整棋盤大小，其後每場 0~N 盤已接上正式流程；決定記錄見 [decisions.json](../../workflows/decisions.json)。本頁保留舊格式的尺寸繼承、限制與相容呈現；新格式每盤明寫 `size`，不繼承舊尺寸欄位，見 [每場格式](encounter-format.md)。場景／規則旗標及模組檔案決定能力是否可用，遭遇另決定盤集合：合法 0 不建 Battlefield，明確正盤缺能力拒絕開場，只有 legacy 保留無模組 fallback。未掛載時不解析模組幾何；核心仍驗格式與新舊欄位衝突。

## 內容包怎麼寫

以下為 legacy 尺寸寫法，不必改程式。寬高各自指定，雙盤可以兩盤不同；座標為 `[x, y]`，x 由 0 到寬−1、y 由 0 到高−1。舊部署政策將玩家放在最後兩列、生成放在最前兩列；新格式由明確部署政策指定位置，不從座標方向推定陣營。

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

預設上限 12 的原始依據是 legacy 的 460×280 px 畫面槽（雙盤左右並列）：12 列時格寬約 23 px、角色縮放約 0.18；16 列約 17.5 px。現行每盤仍保留 16×16 硬上限，新格式的呈現矩形則由內容另給，不能將上述槽尺寸或可讀性估計當成 N 盤的固定排法或盤數限制。尋路、威脅預覽與 AI 都按實際格數計算，未針對效能另作量測。

## 驗證與錯誤

正式開場由 PreparedEncounter 在裝配前呼叫模組正規化器，驗證尺寸與盤內格；legacy 經 `BoardSetup.from_legacy`，新格式經 `from_explicit`／`from_definitions`。無效資料拒絕整次開場，代碼與說明由場景 `last_start_error` 保留，不降級成無盤戰鬥。主角 footprint 等部署可放性再由暫存 setup 檢查；完整失敗與重試邊界見 [開始與清理](encounter-lifecycle.md)。

下表為 legacy 尺寸驗證代碼；說明包含遭遇 id、盤名或出錯欄位，例如「board "party" deploy_cells [3, 2] is outside the 3x3 board (x 0..2, y 0..2)」。新格式正規化器使用 `invalid_board_definition_size`／`invalid_board_definition_cells` 等代碼，兩條路徑都拒絕無效尺寸與盤外格，不靠夾值或略過修正內容。

| 代碼 | 情況 |
|---|---|
| `invalid_board_size_limits` | 規則的上下限或預設大小自相矛盾、超過 16×16 |
| `invalid_encounter_board_size` | size 不是兩個整數，或只有一軸 ≤ 0 |
| `encounter_board_size_out_of_range` | size 超出規則允許範圍 |
| `encounter_cell_out_of_bounds` | 部署、生成、障礙、初始場域或波次單位格超出所在盤 |
| `invalid_encounter_board`／`invalid_encounter_wave_board` | 盤名不屬於目前模式 |

legacy 波次單位沒寫 `cell` 沿相容生成位置與落格政策處理；寫了但在盤外則屬錯誤。作者可帶內容包跑 Smoke，其 loaded Encounter probe 逐一驗證舊尺寸／位置欄位。這不等於逐一驗完新格式內容；新格式由正式 Prepared 開場驗證，schema 專項的範圍見 [suite coverage](../../workflows/testing/suite-coverage.md)。

## 呈現

[BoardView](../../../game/scripts/ui/BoardView.gd) 的 `compute_layout` 依實際盤大小與傳入槽尺寸取最大正方格（上限 64 px）；角色縮放由 [BoardActorPresentation](../../../game/scripts/ui/BoardActorPresentation.gd) 的 `actor_scale_for` 依格寬計算。legacy 相容槽仍是 460×280：雙盤左槽 x=70、右槽 x=640，單盤 x=360，y=170。[BoardCombatPresentation](../../../game/scripts/ui/BoardCombatPresentation.gd) 使用每個穩定 ID 對應的矩形；新格式明確提供所有矩形，改槽或重排不改盤大小、單位 anchor 或 faction。

## 證據與未驗

[board_size_cases](../../../tests/board_size_cases.gd)（Board suite）驗 legacy 預設不變、3×3、8×6、不對稱雙盤、規則收窄／放寬、各類錯誤訊息與版面數值；Smoke loaded Encounter probe 驗舊欄位。新格式集合、正式 0→正盤切換與能力錯誤見 [整合實證](../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)。真正 NONE 與刪除模組檔由 Boardless／BoardRemoved 回歸。這些是 headless 數值與流程斷言：各尺寸的實際觀感、字級、角色遮擋與滑鼠命中都未驗，屬使用者人工驗收項。
