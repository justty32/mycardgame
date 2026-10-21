# testing/suite-coverage — 各 suite 實際驗了什麼

[testing](../testing.md)｜[runner 與 suite](suites.md)

逐一列出 runner 各 suite 的入口、完成標記與涵蓋範圍，供選 suite 與寫報告時對照；執行順序以 runner 的 `ALL_SUITES` 為準。

**何時用**：要判斷某個改動會被哪個 suite 抓到，或報告裡要寫清楚某次 PASS 涵蓋到哪裡。

**何時不用**：要決定該補哪些新測試 → [validation](../game-dev/validation.md)；要跑 runner 或接新 suite → [suites](suites.md)。

所有 suite 通過都不代表全部卡牌、遭遇或自訂內容已驗證；fixture 與結果見各報告。

## 每場準備（Smoke／DualBoard）

Smoke 呼叫 [prepared_encounter_probe.gd](../../../tests/prepared_encounter_probe.gd)，驗未知遭遇不提前掛載、只解析一次、Event／Rules／Encounter 巢狀快照隔離與舊模式相容。DualBoard 呼叫 [prepared_start_cases.gd](../../../tests/prepared_start_cases.gd)，在正常戰鬥停止後驗無參數裝配不復活舊場，再經 Director 相容入口啟動明確不同 Event，核對實際初始效果與首波；另驗當場普通卡規則與 Director 共用、下一場讀新配置。這些測例不代表每場 0／N 盤新 schema 已實作；結果與限制見 [準備分析](../../../analysis/slay-the-robot/architecture/08_combat_preparation.md)。

## Dictionary、Combat、SaveLoad、ResourceLifecycle

- [Dictionary](../../../tests/dictionary_regression.gd) 走 JSON patch API，涵蓋完整 patch 邊界。
- [Combat](../../../tests/combat_flow.gd)（CombatVictory／CombatDefeat）跑單場戰鬥的勝、敗與獎勵。
- [SaveLoad](../../../tests/save_load_flow.gd) 驗跨程序的語意還原與續玩。
- [ResourceLifecycle](../../../tests/resource_lifecycle.gd) 驗 processor、async／取消與 Root 清理。

## Ctb

入口 [ctb_flow.gd](../../../tests/ctb_flow.gd)，fixture [ctb_fixture.gd](../../../tests/ctb_fixture.gd)，標記 `CTB PASS:`。驗 CTB 時間軸：不同速度的行動順序與刻數、`combat_tick_advanced`、EVERY_N_TICKS 狀態、行動開始時清除格擋、turn_count 等於主角行動數、TimelineBar／TurnOverlay 的文字，以及中途離樹後 Director 會停止。

## Board

入口 [board_flow.gd](../../../tests/board_flow.gd)，cases [board_cases.gd](../../../tests/board_cases.gd)，fixture [board_fixture.gd](../../../tests/board_fixture.gd)，標記 `BOARD PASS:`。驗 7×5 棋盤：

- 移動點與付費移動的延遲；障礙與繞路；
- 射程、CROSS、LINE_PIERCE 與 2×2 佔格；
- 突進、推、拉近、交換、閃現與定身；召喚到最近空格；
- KEEP_RANGE／CHARGE／APPROACH 的移動，以及 ThreatPreview 與實際受傷相等。

開場前先跑純物件的 [board_size_cases.gd](../../../tests/board_size_cases.gd)：每場棋盤大小（預設 5×5 不變、3×3、8×6、不對稱雙盤）、規則上下限、錯誤代碼與說明，以及 BoardView 版面數值；不含實際畫面。

[board_setup_cases.gd](../../../tests/board_setup_cases.gd) 核對任意 ID 定義、驗證與來源隔離；[board_layout_cases.gd](../../../tests/board_layout_cases.gd) 的純物件部分驗顯式矩形映射及槽尺寸。幾何集合不要求敵我目的盤，部署政策另驗；這些是內部接點，不是新序列化格式。

## Wave

入口 [wave_flow.gd](../../../tests/wave_flow.gd)，cases [wave_cases.gd](../../../tests/wave_cases.gd)，fixture [wave_fixture.gd](../../../tests/wave_fixture.gd)，標記 `WAVE PASS:`。驗三波遭遇：wave_started／wave_cleared 的刻數；波與波之間的格擋牌不被短路；登場延遲與錯開；WAIT_UNTIL_FREE 重試後改用最近空格；FAIL_SKIP 跳過；雜兵不擋清波；每波 wave_on_cleared_actions 加錢；最後一波清空才 combat_ended。

Board／Wave 既有的單盤案例以顯式 SINGLE 保持距離契約。棋盤掛載時 `CombatRulesData.board_mode` 預設為 DUAL；場景與規則的 `board_enabled` 旗標預設都開，所以正常新局是掛載的雙盤，未掛棋盤要由 Boardless 明確關閉旗標。

## Field 與 DualBoard

[Field](../../../tests/field_flow.gd)（標記 `FIELD PASS:`）驗場域、ZOC、位移、位置條件與 ordered lifecycle。[DualBoard](../../../tests/dual_board_flow.gd)（標記 `DUAL_BOARD PASS:`）從正常新局走預設雙盤、A targeting、原子 transfer／swap、兩盤場域與本體站格。

兩者各自的 assertions 與實際執行結果見 [雙盤驗收表](../../specs/dual-board/verification.json)。工程仍在整合時，不能拿舊的 All 結果代替新增 suite。

DualBoard 另呼叫 board_layout_cases 的實場部分，驗三個任意 ID、同 ID 改槽及重排不改 membership；[board_spawn_policy_cases.gd](../../../tests/board_spawn_policy_cases.gd) 驗首波內部不受畫面槽限制的生成，以及舊顯式 Encounter 的 positional 截斷預設。B 結果另見 [盤定義分析](../../../analysis/slay-the-robot/architecture/09_board_setup_layout.md)，不取代 C 的真實 0→正盤→0 開場驗收。

## Boardless

入口 [boardless_flow.gd](../../../tests/boardless_flow.gd)。四個程序共用同一隔離副本，以 `--boardless-phase=write/read/defeat/scene_off` 分別驗關閉棋盤時的戰鬥、存讀、死亡，以及場景開關。每個階段都要求整行 `BOARDLESS PASS: <phase>`，任一失敗即停止。棋盤相關改動須與 DualBoard 一起跑，見 [validation](../game-dev/validation.md#棋盤開關兩種模式都要驗)。

## BoardRemoved

與 Boardless 共用 [boardless_flow.gd](../../../tests/boardless_flow.gd)，但 runner 先在隔離副本**刪除棋盤模組檔**（`scripts/combat/board/`、`scripts/actions/board_actions/`、`scripts/validators/board/`、`scripts/ui/Board{View,ActorPresentation,CombatPresentation,Layout}.gd`，清單以 runner 的 `BOARD_MODULE_PATHS` 為準），再以 `--boardless-phase=removed／defeat` 兩階段驗：import 無錯，規則與場景都要求棋盤時仍以普通戰鬥完成出牌、意圖輪替與勝敗。它證明核心不依賴棋盤類別；動到 CombatModule 介面、核心與模組邊界時必跑。標記同為 `BOARDLESS PASS: <phase>`。
