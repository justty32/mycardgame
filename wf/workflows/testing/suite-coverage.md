# testing/suite-coverage — 各 suite 實際驗了什麼

[testing](../testing.md)｜[runner 與 suite](suites.md)

逐一列出 runner 各 suite 的入口、完成標記與涵蓋範圍，供選 suite 與寫報告時對照；執行順序以 runner 的 `ALL_SUITES` 為準。

**何時用**：要判斷某個改動會被哪個 suite 抓到，或報告裡要寫清楚某次 PASS 涵蓋到哪裡。

**何時不用**：要決定該補哪些新測試 → [validation](../game-dev/validation.md)；要跑 runner 或接新 suite → [suites](suites.md)。

所有 suite 通過都不代表全部卡牌、遭遇或自訂內容已驗證；fixture 與結果見各報告。

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

## Wave

入口 [wave_flow.gd](../../../tests/wave_flow.gd)，cases [wave_cases.gd](../../../tests/wave_cases.gd)，fixture [wave_fixture.gd](../../../tests/wave_fixture.gd)，標記 `WAVE PASS:`。驗三波遭遇：wave_started／wave_cleared 的刻數；波與波之間的格擋牌不被短路；登場延遲與錯開；WAIT_UNTIL_FREE 重試後改用最近空格；FAIL_SKIP 跳過；雜兵不擋清波；每波 wave_on_cleared_actions 加錢；最後一波清空才 combat_ended。

Board／Wave 既有的單盤案例以顯式 SINGLE 保持距離契約，DUAL 為正常新局的預設。
<!-- TODO(程式 agent)：棋盤改為可選掛載模組後，「DUAL 為正常新局預設」是否仍成立（或預設為未掛棋盤）請依程式確認後改寫。 -->

## Field 與 DualBoard

[Field](../../../tests/field_flow.gd)（標記 `FIELD PASS:`）驗場域、ZOC、位移、位置條件與 ordered lifecycle。[DualBoard](../../../tests/dual_board_flow.gd)（標記 `DUAL_BOARD PASS:`）從正常新局走預設雙盤、A targeting、原子 transfer／swap、兩盤場域與本體站格。

兩者各自的 assertions 與實際執行結果見 [雙盤驗收表](../../../analysis/slay-the-robot/design/dual-board/verification.json)。工程仍在整合時，不能拿舊的 All 結果代替新增 suite。

## Boardless

入口 [boardless_flow.gd](../../../tests/boardless_flow.gd)。四個程序共用同一隔離副本，以 `--boardless-phase=write/read/defeat/scene_off` 分別驗關閉棋盤時的戰鬥、存讀、死亡，以及場景開關。每個階段都要求整行 `BOARDLESS PASS: <phase>`，任一失敗即停止。棋盤相關改動須與 DualBoard 一起跑，見 [validation](../game-dev/validation.md#棋盤開關兩種模式都要驗)。
