# 卡牌取得入口與測試接線

[卡牌設計](../card-design.md)｜[內容接線](../content.md)｜[驗收分流](../validation.md)

**何時用**：卡已有 schema，要接進卡包、起始牌組或獎勵，並安排能實際跑到這張卡的驗收。

**何時不用**：從零登記 mod 與資料夾，先照 [第一個 mod](../content/bootstrap.md)；只改卡的效果或數值，回 [卡牌設計](../card-design.md)。

## 接入卡包與取得入口

按 [content](../content.md) 為 mod 登記 cards→`CardData`／`_id_to_card_data`；若新增卡包，再登記 card_packs→`CardPackData`／`_id_to_card_pack_data`，並在 mod_list 啟用、記錄優先順序。卡包、角色 patch 都用同一個 JSON 外殼；同 ID 修改須明定每欄的 patch 策略（見 [RNG 與資料契約](../mechanics/rng-data.md#序列化與-patch-策略)）。

起手與獎勵是兩個分開接線的欄位，要分開驗。卡包篩選順序（明列 ID 最後 include、可繞過前面篩選）、玩家黑白名單次序與稀有度 bucket 行為見 [核實筆記的取得、稀有度與曝光](../../../../analysis/slay-the-robot/design/cards.md#取得稀有度與曝光)。

完整重啟隔離副本，以重建 Global pack cache，再用新 run 驗起手；查玩家 draft cache 與稀有度 bucket，然後走實際的獎勵選牌把卡加入 deck。稀有度權重、保底狀態與池內同稀有度的卡數共同影響出現率，改成 RARE 不只是改標籤；不能用「卡已註冊」代替取得驗證。改 ID 或永久牌欄位時，接上存讀相容驗證。

不要為每張卡另建 pack。任務沿用 `character_red` 時，現有 `card_pack_red` 已篩 `color_red`；COMMON ATTACK 且 appears=true 的新卡可直接納入，但仍須斷言 cache／bucket 與真實取得。只有需要獨立的取得範圍才新增 pack。模組從零登記依 content，不要把官方 example_mod 的全卡欄位當成新 schema。

## 將驗收接進可跑的測試

現有 Combat fixture 覆寫起始牌組、扣費斷言固定，runner 只接受固定的 suite 清單（見 [核實筆記的現有工具](../../../../analysis/slay-the-robot/design/cards.md#現有工具能證明什麼)），不會因 mod 新增卡而自動測到該卡。要安排專項的載入、出牌、升級與取得 assertions，交 runner owner 接入隔離執行與完成標記，不得虛構 `--suite Cards` 之類的命令；內容包的完整流程走 PackScenario（見 [題材內容包](../content/pack.md)）。已有 Smoke／Combat 成功只作基準。盤面專屬卡另依 [棋盤開關](../validation.md#棋盤開關兩種模式都要驗) 跑兩種模式。
