# 非戰鬥事件、商店、休息與寶箱：來源核實

[操作流程](../../../wf/workflows/game-dev/level-design/noncombat.md)｜[敵人與地圖](encounters.md)｜[全局流程](../../../wf/workflows/game-dev/game-flow.md)

2026-10-19 靜態查核本機 game，基準為上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加現有本地修復。本次沒有啟動 Godot、操作 UI 或驗新事件；以下是來源事實與待驗邊界，非完整非戰鬥流程通過報告。

## 種類路由與資料註冊

[LocationData](../../../game/data/mutable/LocationData.gd) 的 EVENT、SHOP、REST_SITE、TREASURE 是四種節點。EVENT 交 [DialogueOverlay](../../../game/scripts/ui/DialogueOverlay.gd)，REST_SITE 交 [RestOverlay](../../../game/scripts/ui/RestOverlay.gd)；[Combat](../../../game/scripts/ui/Combat.gd) 對 SHOP／TREASURE 只顯示場景裡 Shop／Chest 按鈕，沒有啟動戰鬥。EventData 的 dialogue ID 只供 EVENT 使用；設施不是用 event 加 reward/price/rest 欄位生成。

[Global.SCHEMA](../../../game/autoload/Global.gd) 與 [base mod_info](../../../game/external/data/mod_info.json) 登記 DialogueData → `_id_to_dialogue_data`、RestActionData → `_id_to_rest_action_data`，以及 events/event_pools/acts。DialogueStateData／DialogueOptionData 是嵌入 dialogue 的物件，沒有獨立 Global 表。獨立 mod 的 envelope、資料夾映射與啟用順序依 [content](../../../wf/workflows/game-dev/content.md)；載入後逐一驗 Global getters 與跨 ID 引用，不以檔案存在為已接線。

## 選項事件的最小構造

[DialogueData](../../../game/data/readonly/DialogueData.gd) 保存 `dialogue_initial_dialogue_state_object_id`、`dialogue_state_id_to_dialogue_states`、`dialogue_option_id_to_dialogue_options`。[DialogueStateData](../../../game/data/readonly/embedded/DialogueStateData.gd) 保存 prompt、圖片及 `dialogue_state_dialogue_option_object_ids`；[DialogueOptionData](../../../game/data/readonly/embedded/DialogueOptionData.gd) 保存文字、actions、validators、失敗是否可見、失敗文字與 next-state ID。這兩個 typed 字典不能當普通 Dictionary 深合併。

GDScript 範例是 [GlobalTestDataGenerator](../../../game/autoload/GlobalTestDataGenerator.gd) 的 `add_test_dialogue()`：先建 dialogue 與選項，用 `_assign_option()` 放入選項字典，再建 state 加 option IDs，以 `_assign_state()`／`_assign_initial_state()` 指定狀態。`add_test_events()` 把 `event_pick_something.event_dialogue_object_id` 設為 `dialogue_pick_something`，再進 `event_pool_act_1_dialogue`，由 Act 的 non-combat pool 引用。預設生成器只按機率將 COMBAT 改為 EVENT，不保證每局出現指定事件。

第一選項 `dialogue_pick_something_option_1` 是扣 10 HP／加 100 money，validator 的 health_amount=11。第二選項是扣 50 money／獲得一張隨機 rare card，money validator=50。這只是內建測試內容；沒有成本欄會自動扣款。兩個 validator 都用 >=，具體來源為 [ValidatorPlayerHealth](../../../game/scripts/validators/ValidatorPlayerHealth.gd)、[ValidatorMoney](../../../game/scripts/validators/ValidatorMoney.gd)。效果走 [ActionAddHealth](../../../game/scripts/actions/combatant_actions/ActionAddHealth.gd) 與 [ActionAddMoney](../../../game/scripts/actions/combatant_actions/player_actions/ActionAddMoney.gd)，仍會經 action interception，不能只由文字推導最終結果。

## 選項執行與退出

[DialogueOption](../../../game/scripts/ui/general/DialogueOption.gd) 在 `init()` 評估 validator，存 option_enabled；輸入 handler 只看這個已存值。DialogueOverlay 建立按鈕後可依 `dialogue_option_visible_on_failed_validation` 隱藏鎖定選項。若可點數為零，就生成 ID 為空的錯誤離開選項；這是防卡死的 fallback，不是設計好的正常退路。

選擇後 Overlay 用玩家建立 fake CardPlayRequest，`ActionGenerator.create_actions()` 建立 payload，呼叫 [ActionHandler.add_actions](../../../game/autoload/ActionHandler.gd) 預設 `enqueue=false`。每個 action 各成一個 stack queue，pop_back 因而反序執行：範例 `[扣 HP, 加 money]` 先加錢再扣血。嵌套 action 仍可增加待執行工作，涉及時序必須實測，不把陣列文字順序當契約。

Overlay 等 actions_ended 後，死亡則結束；next ID 空也結束；非空但找不到 state 同樣結束。合法 next state 則重新建立選項與 validators。`dialogue_ended` 由 [Map](../../../game/scripts/ui/Map.gd) 在玩家存活時開地圖、恢復移動，死亡則隱藏地圖。初始 state 遺失沒有同樣保護，start_dialogue 直接將查得結果交 populate，內容應先靜態拒絕壞 initial ID。

Overlay 的選擇 handler 沒有再次驗 validators 或全域忙碌鎖；也沒有跨多個 action 的交易回滾。正常按鈕 gating 不等於可安全接受任意重複 handler 呼叫。需要原子扣款／一次性領取／動態鎖定的內容，必須補針對性機制與測例；本次只記來源限制，未重現執行漏洞或修改遊戲。

## 商店的商品、價格與購買

[Shop](../../../game/scripts/ui/Shop.gd) 發 shop_opened；[ShopOverlay](../../../game/scripts/ui/ShopOverlay.gd) 取得或生成目前位置的 [ShopData](../../../game/data/mutable/ShopData.gd)，再呼叫 `visit_shop()`。首次由 rng_shop 生成卡、遺物、消耗品與價格，交 [ActionShopPopulateItems](../../../game/scripts/actions/shop_actions/ActionShopPopulateItems.gd) 填入商品／價格平行資料。數量常數、稀有度價格範圍在 ShopData，其他定價計算在 [Random](../../../game/autoload/Random.gd)，不是 ActData 或 EventData 設定。

每個商品按鈕帶 [ActionShopPurchaseItems](../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd)；它重新讀 shop 的實際價格及玩家金錢，足額才排獲取／扣款、下架及發 purchased。消耗品另查玩家槽位是否滿。這裡不能只驗 UI 紅字；需要資源差值、入庫、下架與重複輸入測例。該 action 沒有全面的已售出請求拒絕保證，例如卡牌不在庫存時 `get_shop_card_price()` 回 0，故不能把過期 action 重放視為已驗安全。

目前 populate_shop 只建立卡、遺物、消耗品按鈕，未建立移除卡牌服務。ShopData 是 PlayerData 的匯出嵌入物件；通常訪問新位置會清除它。Continue 可以在 act 結尾生成下一幕；Map 在 shop_opened 已允許移動，具體地圖入口與呈現仍需 runtime 驗證。

## 休息的可用選項與次數

RestOverlay 讀 [PlayerData](../../../game/data/prototype/PlayerData.gd) 的 `player_available_rest_action_object_ids`，用 [RestActionData](../../../game/data/readonly/RestActionData.gd) 產生 [RestActionButton](../../../game/scripts/ui/RestActionButton.gd)。資料定義 actions、validators、cost type、auto-end 與統計 ID。EXCLUSIVE 執行後排除所有 exclusive；INCLUSIVE 排除自己；INCLUSIVE_REPEATABLE 不排除。排除狀態存在按鈕物件，沒有寫成位置上的已用次數。

`rest_action_auto_end=true` 時 Overlay 把 rest-end 推到陣列最前，經 stack 反序後在其餘效果後消耗次數。可取消選牌應把 auto-end 關掉，改由成功選牌的嵌套 payload 發結束；範例在 generator 的 `add_test_rest_actions()`。原版 rest 是 40% 治療、exclusive；upgrade 是 inclusive-repeatable 且可取消，remove-card 是 inclusive。玩家預設可用清單與自訂 action 是否加入清單須另外驗，不能只註冊資料。

## 寶箱獎勵與未完成欄位

[Chest](../../../game/scripts/ui/Chest.gd) 點擊後先隱藏，呼叫 `generate_chest_open()` 再發 chest_opened。[ActionOpenChest](../../../game/scripts/actions/world_interaction_actions/ActionOpenChest.gd) 生成 money/card drafts/artifact IDs/custom actions，交 [ActionGrantRewards](../../../game/scripts/actions/rewards/ActionGrantRewards.gd) 再由 [RewardOverlay](../../../game/scripts/ui/RewardOverlay.gd) 顯示。參數例如 chest_has_money、chest_generates_money、chest_money 屬 action，不屬 EventData；指定遺物 ID 的 key 實際是 `artifact_ids`。

consumables 區塊整段 TODO 註解，雖讀了 chest_has_consumables，仍未填 consumable_ids；此旗標不能證明掉落能力。Chest 隱藏不等於持久化已領取：LocationData 沒有已開箱欄位，再次進入 TREASURE 時 Combat 會再次顯示按鈕。一次性與存讀需另驗，不能以一次顯示成功宣稱完整。

## 保存與幕尾邊界

[ActionVisitLocation](../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 先改位置、清 shop、autosave，再發訪問訊號。[FileLoader.load_game](../../../game/autoload/FileLoader.gd) 讀入 PlayerData 後重發 run_started 與目前位置的 map_location_selected；它不重跑 ActionVisitLocation，因此有保存的 ShopData 不因這次讀檔訊號而被該 action 清除。但通常 autosave 發生在開店／交易之前，不能只由資料可匯出便宣稱每次交易已保存。Dialogue 的當前 state 與 Rest 的 excluded 只在 UI，位置也沒有已開箱快照；現有自動保存是互動前的位置邊界。

Shop Continue／Reward Continue 有 generate_next_act；Rest Continue 沒有；Dialogue 結束只回 Map。因此 EVENT／REST 作非最終幕的死端時沒有相同轉幕路徑。最終戰由 RunSummary 的 combat_ended 判斷直接 run_victory，不顯示一般戰後獎勵。整體狀態路由依全局流程核對。

現有 Combat／SaveLoad 沒有覆蓋上述全部選項／設施。新內容要有真正路線到達、選項門檻、拒絕無副作用、時序、取消／死亡／返回、重複操作與跨程序下一步測例；新增 suite 接入 runner 後才記為可執行命令。此輪僅靜態核實，所有這類 runtime 行為仍未因本篇而獲得通過證據。
