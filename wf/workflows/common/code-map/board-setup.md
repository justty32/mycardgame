# code-map／盤定義、部署與排版

[戰鬥框架](combat-framework.md)｜[遷移 B 分析](../../../../analysis/slay-the-robot/architecture/09_board_setup_layout.md)

幾何輸入由 [BoardSetup](../../../../game/scripts/combat/board/BoardSetup.gd) 驗證為 ID 集合，舊 Encounter 與 mode 只在 `from_legacy` 轉譯。[BoardDeployment](../../../../game/scripts/combat/board/BoardDeployment.gd) 是獨立的位置政策，不生成單位或寫占格；幾何 factory 不要求 party／enemy 目的盤。[CombatBattlefield](../../../../game/scripts/combat/board/CombatBattlefield.gd) 消費定義建盤，保留舊建構與預設盤 getter 的相容轉送。

[BoardLayout](../../../../game/scripts/ui/BoardLayout.gd) 只映射穩定 ID 到畫面矩形；[BoardView](../../../../game/scripts/ui/BoardView.gd) 接收槽尺寸，[BoardCombatPresentation](../../../../game/scripts/ui/BoardCombatPresentation.gd) 管理 View 與 actor 映射，重排不回寫世界。

[UnitSpawner](../../../../game/scripts/combat/UnitSpawner.gd) 的首波相容選項分開實體生成與舊事件畫面槽限制，後續仍共用 placement admission。Prepared 依 legacy／明確正盤格式選路，不能依 Event ID 猜新語意。外部欄位見 [資料格式](../../../specs/board-module/encounter-format.md)，驗證入口見 [suite coverage](../../testing/suite-coverage.md)。
