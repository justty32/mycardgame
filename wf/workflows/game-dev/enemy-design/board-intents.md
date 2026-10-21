# 敵人的棋盤意圖與模組開關

[敵人設計](../enemy-design.md)｜[棋盤意圖核實](../../../../analysis/slay-the-robot/design/board-intents.md)｜[可選棋盤模組](../mechanics/board-module.md)｜[驗收分流](../validation.md#棋盤開關兩種模式都要驗)

**何時用**：敵人意圖含移動、射程、跨盤目標或盤面專屬 payload，或要確認同一敵人在掛棋盤與未掛棋盤時都能運作。

**何時不用**：只有普通攻擊／格擋／custom actions、不碰棋盤的意圖，回 [敵人設計](../enemy-design.md) 即可，但仍要跑兩種模式的回歸。

## 雙盤定位

先指定來源與目標的實際 `board_id`；幾何入口、盤身分與陣營分離、跨盤 A 的形狀與方向型拒絕見 [核實](../../../../analysis/slay-the-robot/design/board-intents.md#盤身分與唯一幾何入口)。測例須包含 SINGLE 卡內巢狀推拉、request 值覆寫、全域／隨機目標，以及拒絕時費用與位置不變。只有 UI 拒絕不涵蓋自動出牌與複製出牌。

## 模組開關的邊界

先驗模組 on/off 邊界（`--suite Boardless` 加 `--suite DualBoard`）。NONE 路徑的目標規則、BoardContentPolicy 整體拒絕與來傷預覽、有模組但缺盤身分時的拒絕，見 [核實](../../../../analysis/slay-the-robot/design/board-intents.md#可選模組與普通戰鬥)；斷言重點是普通攻擊、格擋、custom 與音效保留，盤面 payload 不能部分執行。這些契約來自靜態核對，實測以兩個 suite 的實際輸出為準。拒絕後下一次行動的意圖推進見 [敵人設計](../enemy-design.md#將意圖寫成完整狀態圖)。

## 移動意圖

移動意圖至少對照預覽與真正 controller 的落點、命中與次序，覆蓋 move_after、rooted、禁閃現格、CHARGE 穿越去重及中途死亡／退出。NEAREST／FARTHEST 的同盤比較與 uid fallback、跨盤 ComputeBoardValue 的拒絕見 [核實](../../../../analysis/slay-the-robot/design/board-intents.md#意圖與預覽)。新自訂 payload 的估值未被標準預覽涵蓋時，另補實作與回歸，不能用數值 0 表示已模擬。此段依 2026-10-20 的靜態接線核對，實測以 DualBoard 等回歸輸出為準。
