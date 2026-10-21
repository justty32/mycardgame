# 商店畫面 — 比較、交易與離開

[場景目錄](README.md)｜[休息服務](rest-services.md)｜[共用元件](../components-layout.md)｜[互動契約](../interaction-states.md)｜[驗證接線](../verification.md)｜[設施內容規則](../../level-design/noncombat.md)

本篇管商店完整畫面，並是商店程式事實的單一來源（[商店的程式事實](#商店的程式事實)）；休息營地的完整畫面在 [休息服務](rest-services.md)。

**何時用**：商店的完整畫面：商品陳列、價格與餘額、購買結果、售罄與離開。

**何時不用**：改供貨／定價／恢復量／次數走 [設施內容規則](../../level-design/noncombat.md)；休息服務走 [休息服務](rest-services.md)；製圖走 [美術](../../art-assets.md)。

## Done when

- 規格／結果檔記錄資料、資源差值、正常／拒絕／取消／退出斷言及未驗項。
- fixture 已接到 caller 並有結果；文件 lint 通過（見 [testing](../../../testing.md)）。
- Smoke／Combat 綠燈不代表設施已驗，交付時分開列出。

## 流程

### 先組成玩家能判斷的畫面

商店讓玩家比較商品／價格與餘額、購買後確認已入庫，再返回路線。素材包含背景／框、商品卡面、遺物／消耗品圖示、貨幣、不可用／售罄提示及 Continue。CardShopButton 重用 Card，尺寸 144×208，價格位於卡面下方；不可用狀態不能只靠紅色表達。圖像接 [介面素材](../../art-assets/interface-assets.md)，演出接 [對話與商店動態](../../art-assets/motion/dialogue-shop.md)。

### 商店的真實接點

[Root.tscn](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Combat/Shop`（[Shop.gd](../../../../../game/scripts/ui/Shop.gd)）被點擊時發 `shop_opened`，再由 [ShopOverlay.gd](../../../../../game/scripts/ui/ShopOverlay.gd) 打開 `RunScreen/ShopOverlay`；抵達 SHOP 節點不等於商品已展開。Overlay 內有 CardContainer、ArtifactContainer、ConsumableContainer、ContinueButton，固定 1200×700、z_index=10。金錢沿 Combat 的 `%MoneyLabel` 與 `player_money_changed` 顯示；要在遮罩內保留金錢顯示，另接同一資料來源並驗遮擋。

三類按鈕各帶一個 `ActionShopPurchaseItems`：卡牌用 card_data，遺物用 artifact_id，消耗品用 consumable_object_id／consumable_slot_index；money_amount 是顯示價格的來源。點商品即提交，現況沒有「先選商品再確認」或交易撤銷：卡牌經 Card.card_selected，其他經 Button.button_up，交給 ActionHandler。

### 商店的程式事實

以下五項依 [ShopOverlay.gd](../../../../../game/scripts/ui/ShopOverlay.gd)、[BaseShopButton.gd](../../../../../game/scripts/ui/shop/BaseShopButton.gd)、[ActionShopPurchaseItems.gd](../../../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd) 與 [ShopData.gd](../../../../../game/data/mutable/ShopData.gd) 核對；動態、聲音等領域只引用本節，不另行重述。

**populate_shop 清空重建**。`populate_shop()` 先 `clear_shop()`（三個容器的子節點全部 queue_free），再取或建立當前位置的 ShopData，呼叫 `visit_shop()`（只在首次造訪時生成商品與價格），然後逐一實例化商品按鈕。每次購買後都整批重建，舊按鈕與掛在上面的 tween／listener 會一起失效。

**買不起只染紅價格**。BaseShopButton 只在 `init()` 時比較價格與當下金錢，不足就把 price_label 染成紅色；沒有 disabled、沒有拒絕訊號，也沒有訂閱金錢變動。買不起的商品仍可點擊並入列 Action，由 Action 靜默拒絕（消耗品槽已滿、目前位置沒有商店也一樣靜默）。

**purchased 早於扣款**。Action 重新讀 ShopData 價格與玩家金錢（消耗品另查空槽），成功時只把扣款與取得的 actions **排入** ActionHandler、從 ShopData 移除商品，接著立刻發 `card_purchased`／`artifact_purchased`／`consumable_purchased`。signal 發出時錢與物品都還沒真正變動；Overlay 收到後等 `actions_ended` 才重建。結果要在 action idle 之後驗資料與 UI。

**售罄＝商品消失**。售出的項目從 ShopData 移除，重建後該按鈕就不存在；沒有 SOLD OUT 佔位或售罄資料。想保留售罄格需另設呈現狀態，不加進庫存。

**Continue 隱藏時機**。Continue 可在不購買時離開；幕尾先 `generate_next_act`，未到終局就 `show_map()`，終局則隱藏 Overlay 並發 `run_victory`。一般返回地圖時 Overlay **不會**立刻隱藏，要到下一次 `map_location_selected` 才隱藏（`combat_started`、`player_killed` 也會隱藏並清空），所以從 Map 按 Back 可能回到商店。

### 商店狀態與缺口

正常狀態顯示名稱／圖示／價格／餘額。空貨架只有空容器；無 ShopData 或無效 ID 需要補錯誤文案。買不起與滿槽目前靜默拒絕，須補拒絕原因的呈現。

連點與過期 action 要測：已下架商品的價格 getter 回 0，Action 缺完整的庫存存在檢查，不保證防止重複購買。防重入需同時驗 UI 與 Action；外部金錢變動時須刷新可購狀態。

商店的移除／升級服務尚未接入；[CardRemovalShopButton.tscn](../../../../../game/scenes/ui/shop/CardRemovalShopButton.tscn) 只是佔位的 Button／PriceLabel，未被 Overlay 實例化。付費服務須先定義價格、合法牌、取消時是否扣款與限次，再接選牌成功的 payload；開啟選牌不等於成交，休息服務也不是交易 API。退出、重開與 pending 購買要驗互斥。

### 聲音、動畫與生命週期

設施腳本沒有專屬播放接線。[商店 cue](../../audio/shop-cues.md) 在扣款／入庫完成後播成功聲，拒絕要有明確結果事件；入庫標記動畫需新增，時序見 [對話與商店動態](../../art-assets/motion/dialogue-shop.md)。關閉時停止自建 tween／音訊／timer，await actions_ended 之後先確認 owner 仍有效。

### 專項 fixture 與驗收

依 [verification](../verification.md)，在 autoload ready 後 runtime load 建議的 tests/ui_shop_rest_probe.gd（尚未建立）。節點／素材檢查接在 Smoke 的 Root ready 之後；互動另建設施情境，沿 Combat `_scenario()` 的起局／固定 seed／map button 模式，配置可達的 SHOP→REST_SITE→下一節點，呼叫 Shop.button_up 進商店。新 suite 由 runner owner 接 SUITE_CHOICES（及 ps1 的 ValidateSet）、分支、mapping、PASS marker／結果。

ShopData fixture 固定商品及價格並標 shop_is_visited，避免重開時隨機重生。分別用 price−1、price、足額／滿槽，記錄交易前後的 money、永久牌組／遺物／消耗品、庫存與按鈕數；售罄、全空、外部金錢改變、重複點擊與 Continue／重開各有斷言。零價 stale action 是待修的失敗案例，不作為正常預期。

同一情境接續的休息專項見 [休息 fixture](rest-services.md#四種-fixture-的具體接法)。背景引擎執行前先排除 [Map 自動焦點](map.md#演出焦點與離場) 這類會動到真實焦點的分支；視覺、命中與聽感另列未驗。

## 交接

交付商品 payload、素材顯示框、fixture／caller、資料差值與缺口。依 2026-10-19 固定上游及本地補丁靜態核實；runtime／視覺／輸入／聽感未驗。
