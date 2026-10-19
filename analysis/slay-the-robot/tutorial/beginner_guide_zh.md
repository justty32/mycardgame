# Slay-The-Robot：新增卡牌與內容入門

[分析入口](../README.md)｜[進階指南](senior_guide.md)｜[核實紀錄](verification.md)

依匯入 commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 核對，日期 2026-10-19。前置知識是 Godot 4.6 專案操作、JSON 與基本 GDScript。本文範例已對照原始碼；尚未將範例 mod 實際寫入遊戲或驗收玩法。

## 資料從哪裡來

[Global.gd](../../../game/autoload/Global.gd) 的 `_ready()` 先產生 schema、讀取設定，再呼叫 `GlobalTestDataGenerator.generate_test_data()`，最後由 `FileLoader.load_read_only_data()` 載入外部資料。生產資料產生器的呼叫目前被註解。因此內容同時有 GDScript 產生器與 JSON mod 兩條來源，並非每張內建卡都存在 JSON 檔。

卡牌欄位以 [CardData.gd](../../../game/data/prototype/CardData.gd) 為準；行動路徑查 [Scripts.gd](../../../game/autoload/Scripts.gd)，參數則查對應 action 的 `get_action_value()` 或 `get_shadowed_action_values()`。Action 執行效果，Validator 檢查條件，Interceptor 調整指定行動的處理。

## 建立獨立模組

以下路徑皆相對 `game/`；引擎中的 `res://` 也指向此目錄。

1. 建立 `external/mods/mycardgame/`，內含 `cards/`、`characters/` 和 `mod_info.json`。
2. 依下方設定註冊資料夾。載入器只讀 `mod_folder_to_load_data` 登記的資料夾，不會因為新增目錄就自動載入。
3. 在 [mod_list.json](../../../game/external/mod_list.json) 的 `properties.mod_load_data` 保留原設定，新增 `"external/mods/mycardgame/": {"enabled": true, "load_priority": 10}`。優先數字較大者較晚載入。

`mod_info.json` 的最小設定：

```json
{
  "properties": {
    "object_id": "mod_data_mycardgame",
    "mod_name": "My Card Game",
    "mod_folder_to_load_data": {
      "external/mods/mycardgame/cards/": {
        "class_name": "CardData", "table_name": "_id_to_card_data"
      },
      "external/mods/mycardgame/characters/": {
        "class_name": "CharacterData", "table_name": "_id_to_character_data"
      }
    }
  }
}
```

依據：[FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()`、[ModListData.gd](../../../game/data/readonly/modding/ModListData.gd) `get_sorted_enabled_mod_folder_list()`。上游 [example_mod](../../../game/external/mods/example_mod/mod_info.json) 還會替換除錯腳本；自己的模組不必照搬該替換設定。

## 第一張卡：重擊

將以下內容存為 `external/mods/mycardgame/cards/card_heavy_strike.json`。未指定的欄位使用 `CardData` 預設值。

```json
{
  "properties": {
    "object_id": "card_heavy_strike",
    "card_name": "重擊",
    "card_description": "造成 [damage] 點傷害。",
    "card_color_id": "color_red",
    "card_type": 0,
    "card_rarity": 1,
    "card_energy_cost": 2,
    "card_requires_target": true,
    "card_appears_in_card_packs": false,
    "card_values": {"damage": 15, "number_of_attacks": 1},
    "card_play_actions": [{
      "res://scripts/actions/combatant_actions/ActionAttackGenerator.gd": {}
    }],
    "card_texture_path": "external/sprites/cards/red/card_red.png"
  }
}
```

`card_type` 的 0、1、2 依序是攻擊、技能、能力；`card_rarity = 1` 是普通。`card_values` 供行動及描述使用。攻擊產生器讀取 `damage` 與 `number_of_attacks`，再建立實際攻擊行動；見 [ActionAttackGenerator.gd](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) `perform_action()`。此處關閉卡包收錄，先以固定起始牌組驗證。

新增 `external/mods/mycardgame/characters/character_red.json`：

```json
{
  "patch_data": {"character_starting_card_object_ids": "append"},
  "properties": {
    "object_id": "character_red",
    "character_starting_card_object_ids": ["card_heavy_strike"]
  }
}
```

這是在既有角色加一張牌，不是完整的新角色定義。相同 `object_id` 會套用補丁；新 ID 才會建立新資料物件。可對照上游 [角色補丁](../../../game/external/mods/example_mod/characters/character_red.json) 與 `Global.start_run()`。

## 抽牌與敵人擴充

抽兩張牌的 action 片段如下；獨立抽牌技能通常設 `card_requires_target: false`。不能使用舊指南的 `draw_amount`。

```json
{
  "res://scripts/actions/combatant_actions/player_actions/ActionDrawGenerator.gd": {
    "draw_count": 2
  }
}
```

參數證據是 [ActionDrawGenerator.gd](../../../game/scripts/actions/combatant_actions/player_actions/ActionDrawGenerator.gd) `perform_action()`。多個 action 的先後順序另見進階指南，不能直接假設陣列正序執行。

敵人不是只填 `enemy_attack_states` 就能運作；該欄位不存在。請先讀 [EnemyData.gd](../../../game/data/prototype/EnemyData.gd) 的 `enemy_intents`、`add_health_bounds()`、`add_intent_state()`，再對照 [測試資料產生器](../../../game/autoload/GlobalTestDataGenerator.gd) `add_test_enemies()` 的 `enemy_1`。敵人以 `EnemyIntentData` 組成有權重的意圖圖，必須有 `intent_initial` 與後續狀態；生成血量使用上下界，不能只改 `enemy_health` 就認定固定血量。

若採 JSON，先從現有物件匯出取得完整巢狀結構：`FileLoader.export_read_only_data()` 是開發輔助功能，預設未呼叫。新增敵人資料夾也須登記 `EnemyData`／`_id_to_enemy_data`，再配置能生成該敵人的戰鬥事件。不要將舊版簡化敵人 JSON 當成可執行模板。

## 驗證步驟

1. 開啟 `game/project.godot`，完整重啟遊戲，使模組重新載入；檢查沒有 JSON 解析、缺少腳本或資料 ID 錯誤。
2. 開始新的紅色角色遊戲，檢查牌組含一張重擊；既有存檔不保證套用新的起始牌組。
3. 進入戰鬥，抽到重擊後選擇敵人，檢查能量減 2、卡牌移出手牌，以及傷害經格擋／狀態修正後的結果。
4. 分別測試抽牌數量、手牌不足／上限與抽牌堆耗盡。這些是待執行的驗收項目，不是本篇已通過的測試。
