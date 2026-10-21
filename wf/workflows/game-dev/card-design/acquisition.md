# 卡牌取得入口與測試接線

[卡牌設計](../card-design.md)｜[內容接線](../content.md)｜[驗收分流](../validation.md)

**何時用**：卡已有 schema，要接進卡包、起始牌組或獎勵，並安排能實際跑到這張卡的驗收。

**何時不用**：從零登記 mod 與資料夾，先照 [第一個 mod](../content/bootstrap.md)；只改卡的效果或數值，回 [卡牌設計](../card-design.md)。

## 接入卡包與取得入口

按 [content](../content.md) 為 mod 登記 cards→`CardData`／`_id_to_card_data`；若新增卡包，再登記 card_packs→`CardPackData`／`_id_to_card_pack_data`，並在 mod_list 啟用、記錄優先順序。卡包、角色 patch 都用同一個 JSON 外殼；同 ID 修改須明定每欄的 patch 策略，普通 Dictionary 合併為淺合併，Array append 不能套給 Dictionary。

起始牌從 `CharacterData.character_starting_card_object_ids` 進新 run；獎勵候選則由 `character_starting_card_draft_card_pack_ids` 指向卡包，兩者要分開驗。卡包依序自動篩顏色、標準類型／稀有度、appears 及 validator，**最後才 include 明列的 IDs**；明列 ID 能繞過前面的篩選。玩家 draft whitelist 又在 blacklist 之後加入，兩者衝突時不要猜黑名單優先。

完整重啟隔離副本，以重建 Global pack cache，再用新 run 驗起手；查玩家 draft cache 與稀有度 bucket，然後走實際的獎勵選牌把卡加入 deck。稀有度權重、保底狀態與池內同稀有度的卡數共同影響出現率，改成 RARE 不只是改標籤。空或耗盡的 bucket 可能給不足張數，不能用「卡已註冊」代替取得驗證。改 ID 或永久牌欄位時，接上存讀相容驗證。

不要為每張卡另建 pack。任務沿用 `character_red` 時，現有 `card_pack_red` 已篩 `color_red`；COMMON ATTACK 且 appears=true 的新卡可直接納入，但仍須斷言 cache／bucket 與真實取得。只有需要獨立的取得範圍才新增 pack。模組從零登記依 content，不要把官方 example_mod 的全卡欄位當成新 schema。

## 將驗收接進可跑的測試

依 [runner](../../../../tools/test_game.py) 與 [fixture](../../../../tests/combat_fixture.gd) 的靜態核對（2026-10-19）：現有 Combat 會覆寫起始牌組，`combat_flow._play()` 的扣費斷言固定為 1，它不會因 mod 新增卡而自動測到該卡。這是靜態結論，不是新卡的執行證據。

要安排專項的載入、出牌、升級與取得 assertions，交 runner owner 接入隔離執行與完成標記。runner 沒有 `--suite Cards` 或任意腳本參數，不得虛構命令；內容包的完整流程走 PackScenario（見 [題材內容包](../content/pack.md)）。已有 Smoke／Combat 成功只作基準。盤面專屬卡另依 [棋盤開關](../validation.md#棋盤開關兩種模式都要驗) 跑兩種模式。
