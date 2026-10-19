# 卡牌資料、取得與評量的核實邊界

本筆記是原始碼核實記憶；操作步驟見 [卡牌設計](../../../wf/workflows/game-dev/card-design.md) 與 [卡牌評量](../../../wf/workflows/game-dev/card-evaluation.md)。2026-10-19 核讀上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復。以下為靜態追蹤，沒有為本筆記啟動 Godot；現有測試證據見 [回歸報告](../architecture/04_regression_validation.md)。

## 原型、執行值與升級

[Global._ready()](../../../game/autoload/Global.gd) 先 `GlobalTestDataGenerator.generate_test_data()`，再讀外部 mod，最後建立卡包 cache。因此新增卡不能只改未啟用的 production generator。新 run 由 CharacterData 起手 ID 生成卡牌 instance，永久牌組在 PlayerData.player_deck；[HandManager.generate_combat_deck()](../../../game/autoload/HandManager.gd) 複製永久牌並設定 parent_card。這是戰鬥修改與永久修改的邊界。

[CardData.gd](../../../game/data/prototype/CardData.gd) 是 schema：描述、能量、類型／稀有度、actions、validators、values、升級、各牌堆去向均有獨立欄位。`card_is_retained` 與 `card_is_ethereal` 可以同時存在；不能只憑自然語言卡詞推導生命週期。官方 [example_mod card](../../../game/external/mods/example_mod/cards/card_modded_card.json) 保留 `card_exhausts`、`card_listeners` 等現行 CardData 未宣告欄位；它展示 JSON 外殼與載入接線，不是最新欄位全集。

[BaseAction.get_action_value()](../../../game/scripts/actions/BaseAction.gd) 先映射 custom_key_names，優先 action values，再 request 的 card_values 快照；若有 card_data，會直接以其 card_values.get(key, default) 返回，並非一定繼續找 player_values。因此不要把簡化的「層層 fallback」當成所有分支契約。卡的可變數字放 card_values 而 action 不重複寫死，才容易讓升級／修改生效。

[GlobalTestDataGenerator.add_test_cards()](../../../game/autoload/GlobalTestDataGenerator.gd) 的 `card_draw` 同時在 card_values 與 ACTION_DRAW_GENERATOR payload 指定 draw_count=3；卡又有升級改善及 decorator。依上述優先序，payload 會遮住同名值變化。這是**靜態辨識的評量陷阱，尚非新增執行回歸證據**；不可直接以該測試卡作升級設計範本。

`CardData.upgrade_card()` 首升先覆寫 value／property，再套每次 improvements；上限受 card_upgrade_amount_max 控制。[ActionUpgradeCards](../../../game/scripts/actions/card_actions/cardset_actions/ActionUpgradeCards.gd) 對選中卡呼叫無參數 upgrade_card()，只有 parent 分支傳 upgrade_count／bypass_upgrade_max。故多次／突破上限的 action 參數不能推定同時作用於戰鬥副本。這不是本輪資源清理修復的一部分；採用時需另驗期望，不在此偷改產品行為。

## 取得、稀有度與曝光

[CardPackData.create_card_pack_card_filter()](../../../game/data/readonly/CardPackData.gd) 的順序為顏色→標準稀有／類型→appears→validators→明列 IDs。最後的 include 可重新加入被篩掉的卡。`card_pack_all` 雖註解說 no filtering，仍走 appears 篩選；不要將註解當作保證。[CardFilter](../../../game/data/filters/CardFilter.gd) 預設取 read-only 卡，取得 instance 要轉 prototype，不能直接修改共用模板。

[PlayerData.regenerate_card_draft_card_filter()](../../../game/data/prototype/PlayerData.gd) 合併玩家卡包後，先 blacklist 再 whitelist，最後依 rarity 建 bucket；黑白名單衝突時白名單重新加回。角色起手 `character_starting_card_object_ids` 與獎勵 `character_starting_card_draft_card_pack_ids` 是分開接線的欄位，載入已有 run 不等於重建起始牌。

[Random.generate_rarity_weighted_card_draft()](../../../game/autoload/Random.gd) 先選 rarity bucket 再取不重複 ID；被選 bucket 不存在或耗盡時不補抽，因此可能不足指定張數。權重依 standard／miniboss／boss／shop 不同；use_pity_system 還讀 player_rare_card_modifier_current。函式內 common 會累加 modifier，`rare_card_found` 雖設 true，當前函式後續未使用它來重置；不能套用別款遊戲的保底假設。實際分布須連初始狀態及連續抽樣順序一起測。

[RewardOverlay.populate_reward_display()](../../../game/scripts/ui/RewardOverlay.gd) 建立 PICK_DRAFT 與 ACTION_ADD_CARDS_TO_DECK；[CardDraftSelectionOverlay](../../../game/scripts/ui/CardDraftSelectionOverlay.gd) 選牌後發確認，亦可跳過。評量需區分卡包含有、獎勵曝光、選取與永久牌組加入。生成候選不代表玩家曾看到或選過。

## 現有工具能證明什麼

[combat_flow.gd](../../../tests/combat_flow.gd) 和 [combat_fixture.gd](../../../tests/combat_fixture.gd) 是固定情境的功能回歸；[save_load_flow.gd](../../../tests/save_load_flow.gd) 驗存讀與續玩。它們沒有通用出牌策略、跨 seed 平衡採樣或人工體驗資料。工作流中的 brief、試驗矩陣、指標和統計要求都是本專案建議契約，不宣稱上游提供模擬器。

本輪未下載或複製 spire-codex 卡牌資料、美術或文字。它仍是可另行研究的參考，不能把外部卡的數值直接當本框架平衡基準；採用任何內容前依 [PROJECT](../../../wf/PROJECT.md) 核對來源條件。
