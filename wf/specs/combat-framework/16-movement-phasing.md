# 移動規則六：分階段分配與 Phase 2b（原移動草案 §9）

[README](README.md)

「Phase 2 增補」已併入 [phases.json](phases.json) 第 2 列（欄位內以「移動增補」標示），新增的 Phase 2b 列在 phases.json（排在 Phase 3 之後、Phase 4 之前）；「題材包補列」已併入 [10-pack-requirements.md](10-pack-requirements.md) 的 [pack-requirements.json](pack-requirements.json)。

## 9.1 分配

分配表（各項屬 Phase 2 或之後）已抽到 [movement-phasing.json](movement-phasing.json)（8 列）。欄位：項目、Phase 2（棋盤）、之後。

**Phase 2b「場域格與控制區」**（**已完成**，9ced42f；suite `Field`）：排在 Phase 3（波次）之後、Phase 4（AI 隊員）之前，讓 AI 的 `pos_score` 一開始就能看到場域與控制區。規模 ~500 行、8 檔；低中風險（純新增，掛在既有 tick／移動訊號上）。Done when：`tests/field_flow.gd`（suite `Field`）——建立 300 刻場域、進入觸發一次、停留在行動開始觸發、過期移除、`field_blocks_movement` 阻擋尋路、`EXTRA_MOVE_COST` 讓可達格集合縮小、`OPPORTUNITY_ATTACK` 對離開者造成 preview 相同傷害、強制位移不觸發控制區但觸發場域進入。
