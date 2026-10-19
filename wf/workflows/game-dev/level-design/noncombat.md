# 非戰鬥事件與設施 — 選擇、代價與離開

[關卡入口](../level-design.md)｜[核實來源](../../../../analysis/slay-the-robot/design/noncombat.md)｜[地圖接線](map-act.md)

**何時用**：帶選項的事件，或商店、休息、寶箱內容及其資源變化。**何時不用**：戰鬥遭遇走 [combat](combat.md)，完整開始／存讀／結算走 [game-flow](../game-flow.md)。

## Done when

設計檔存在，寫明節點種類、選項與門檻、成本／收益、取消／離開／死亡、下一節點及存讀政策。資料 ID 可解析且從路線到達；專項斷言驗合法與拒絕路徑、只執行一次、資源差值、返回與續玩。未執行的 runtime、視覺及輸入驗收明列，文件 strict lint 回傳 0。

## 流程

### 先選真正的內容種類

EVENT 用 DialogueData 狀態機；SHOP 用 ShopData 商品／價格及購買 action；REST_SITE 用玩家可用的 RestActionData；TREASURE 用開箱 action 與 RewardOverlay。它們都是 [LocationData](../../../../game/data/mutable/LocationData.gd) 的種類，不能用 EventData 加任意同名欄位代替。

先定義玩家看見什麼、可拒絕什麼、付出什麼、獲得什麼，以及是否允許致死或取消。設計選擇須有可解釋的取捨；別把「全部鎖住時的錯誤離開按鈕」當正常分支。

### 建一個可運作的選項事件

最短範例在 [GlobalTestDataGenerator.add_test_dialogue()](../../../../game/autoload/GlobalTestDataGenerator.gd)：`dialogue_pick_something` 的第一選項用 10 HP 換 100 money，第二選項用 50 money 換隨機 rare card。數值只是範例；複製前沿 [DialogueData](../../../../game/data/readonly/DialogueData.gd)、[DialogueStateData](../../../../game/data/readonly/embedded/DialogueStateData.gd)、[DialogueOptionData](../../../../game/data/readonly/embedded/DialogueOptionData.gd) 核對 schema。

DialogueData 保存嵌入的 states/options 字典與 initial state ID；State 存 prompt、圖像與可選 option IDs；Option 存文字、validators、actions、失敗顯示與 next state ID。空 next ID 結束事件，非空 ID 應先驗存在；不存在雖也會結束，不能當成功轉移。每個狀態提供可到達的正常出口，或明確測試不可取消的需求。

成本與獎勵由 action payload 實現，文字不會自動扣資源。例如 [ValidatorPlayerHealth](../../../../game/scripts/validators/ValidatorPlayerHealth.gd) 的 `health_amount=11` 以 >= 判斷，可保護扣 10 HP 後至少存活 1；[ValidatorMoney](../../../../game/scripts/validators/ValidatorMoney.gd) 的 `money_amount=50` 保護 50 金錢成本。實際改值走 [ActionAddHealth](../../../../game/scripts/actions/combatant_actions/ActionAddHealth.gd)／[ActionAddMoney](../../../../game/scripts/actions/combatant_actions/player_actions/ActionAddMoney.gd)。GDScript 可用 Scripts 常數，JSON 的 action/validator key 必須是對應腳本路徑；數值和 target override 以 [Scripts](../../../../game/autoload/Scripts.gd) 與 BaseAction 為準。

[DialogueOverlay](../../../../game/scripts/ui/DialogueOverlay.gd) 用玩家作來源／目標並建立 fake CardPlayRequest，交 ActionHandler 的預設 stack 執行，頂層 actions 反序；「先扣成本再給獎勵」須依真實時序排列並斷言。選項按鈕只在建立時驗 validator，handler 沒有通用重驗／回滾。需要重入保護、交易原子性或動態刷新時先交 mechanics，別把兩個 actions 當交易 API。

依 [content](../content.md) 為獨立 mod 登記 DialogueData、EventData、EventPoolData、ActData 的 folders/class/table；states/options 嵌入 dialogue，不另建全域表。Event 的 `event_dialogue_object_id` 指向 dialogue；non-combat pool 接 Act 的 `act_non_combat_event_pool_object_id`。預設生成器按機率將普通戰鬥節點轉 EVENT；若必須出現，設固定 EVENT 位置或自訂生成。接線測例須同時驗「能抽中」與「玩家可走到」。

### 調整商店、休息與寶箱

商店從 [ShopOverlay](../../../../game/scripts/ui/ShopOverlay.gd) → [ShopData](../../../../game/data/mutable/ShopData.gd) `visit_shop()` 生成商品與價格 → [ActionShopPurchaseItems](../../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd) 購買。商品數量／價格範圍不是 ActData 欄位；需要定價或供貨客製先核對真正 action／interceptor 接點。驗足額／不足額、扣款／入庫／下架、消耗品滿槽及重複購買；不能只看標價。現有 ShopOverlay 未建立移除卡牌商品，不因 scene 檔存在宣稱有移除服務。

休息由 [RestOverlay](../../../../game/scripts/ui/RestOverlay.gd) 讀 `player_available_rest_action_object_ids`。新增 [RestActionData](../../../../game/data/readonly/RestActionData.gd) 後還要接入玩家清單；範例在 generator 的 `add_test_rest_actions()`。EXCLUSIVE 互斥、INCLUSIVE 單次、INCLUSIVE_REPEATABLE 可重複。可取消選牌設 `rest_action_auto_end=false` 並在成功 payload 才發 rest-action-end；驗取消不消耗次數。原版 upgrade 是可重複，不可套用其他遊戲的「每次營地只能升級一次」。

寶箱走 [Chest](../../../../game/scripts/ui/Chest.gd) → [ActionOpenChest](../../../../game/scripts/actions/world_interaction_actions/ActionOpenChest.gd) → GrantRewards／RewardOverlay。開箱參數可控制 money/cards/artifacts 與自訂 actions，但需透過真正呼叫或 interceptor 供值，不能加在 event JSON。consumables 生成目前被 TODO 註解，不能只設旗標聲稱會掉落。驗開箱、各獎勵領取／放棄、Continue 與重複開箱。

### 驗出口與存讀

EVENT 正常結束由 Map 返回地圖；REST Continue 與 SHOP／Reward Continue 的轉幕處理不同。非戰鬥放幕尾須依 map-act 補機制／專項，不直接套用 Boss 出口。位置訪問先 autosave 再互動；dialogue state、休息次數與已開箱狀態沒有完整互動快照。設計保存策略時驗當前位置重新進入、下一位置存讀及重複收益，詳見核實來源。

現有 Smoke／Combat／SaveLoad 是框架基準，沒有 NonCombat suite。從 [combat_flow](../../../../tests/combat_flow.gd) 重用隔離場景／等待 action／真實 handler 模式，由 runner owner 接入新專項後才記命令。至少驗每個選項的門檻前／正好門檻、未選項無副作用、結束與死亡；設施按上述資源及次數斷言。執行只用 [背景驗證](../validation.md)，不得開窗或把直接呼叫 action 當路線驗收。

## 交接

交付 schema 與 ID 鏈、選項／設施語意、action 順序、每條分支的驗證結果、退出與存讀政策。真正未實作機制交 mechanics，路線／資源節奏交 map-act，核實事實同步 noncombat 分析。
