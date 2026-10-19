# 商店與休息畫面 — 比較、交易與服務

[UI 入口](../README.md)｜[共用元件](../components-layout.md)｜[互動契約](../interaction-states.md)｜[驗證接線](../verification.md)｜[設施內容規則](../../level-design/noncombat.md)

**何時用**：商店與休息完整畫面。**何時不用**：改供貨／定價／恢復量／次數走設施內容規則；製圖走 [美術](../../art-assets.md)。

## Done when

規格／結果檔記錄資料、資源差值、正常／拒絕／取消／退出斷言及未驗項；fixture 接到 caller 並有結果，文件檢查通過。Smoke／Combat 不代表設施已驗，本篇不授權引擎／GUI。

## 流程

### 先組成玩家能判斷的畫面

商店讓玩家比較商品／價格與餘額、購買後確認入庫，再返回路線。素材包含背景／框、商品卡面、遺物／消耗品圖示、貨幣、不可用／售罄提示及 Continue。CardShopButton 重用 Card，144×208，價格位於卡面下方；不可用狀態不能只靠紅色。

休息讓玩家判斷服務效果／代價、確認或取消選牌，再查看剩餘選項。素材包含背景、服務圖示／名稱／說明、互斥／已用標記及 Continue。RestActionButton 是 240×240 文字 Button，未讀取 `rest_action_texture_path`，須補 consumer。素材接 [介面素材](../../art-assets/interface-assets.md)，演出接 [UI 動畫](../../art-assets/ui-motion.md)。

### 商店的真實接點

從 [Root.tscn](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Combat/Shop`（[Shop.gd](../../../../../game/scripts/ui/Shop.gd)）點擊發 `shop_opened`，才由 [ShopOverlay.gd](../../../../../game/scripts/ui/ShopOverlay.gd) 打開 `RunScreen/ShopOverlay`；抵達 SHOP 節點不等於商品已展開。Overlay 內為 CardContainer、ArtifactContainer、ConsumableContainer、ContinueButton，固定 1200×700、z_index=10。金錢沿 Combat 的 `%MoneyLabel` 與 `player_money_changed`；要在遮罩內保留金錢顯示，另接同一資料來源並驗遮擋。

`populate_shop()` 先清舊節點，再取／建立當前位置 [ShopData](../../../../../game/data/mutable/ShopData.gd)，`visit_shop()` 首次生成商品及價格。三類按鈕各帶 `ActionShopPurchaseItems`，卡牌用 card_data，遺物用 artifact_id，消耗品用 consumable_object_id／consumable_slot_index；money_amount 是顯示價格來源。[BaseShopButton](../../../../../game/scripts/ui/shop/BaseShopButton.gd) 只在 init 將不足金錢的價格染紅，沒有 disabled 或動態金錢訂閱。

點商品即提交，現況沒有「先選商品再確認」或交易撤銷。卡牌經 Card.card_selected，其他經 Button.button_up，交 ActionHandler；[購買 Action](../../../../../game/scripts/actions/shop_actions/ActionShopPurchaseItems.gd) 重新讀 ShopData 價格及玩家金錢，消耗品還查滿槽，成功排入扣款／入庫、移除貨架項並發 purchased signal。Overlay 等 actions_ended 後重建。結果驗 action idle 後的資料及 UI，不在 signal 當下假定扣款完成。

### 商店狀態與缺口

正常顯示名稱／圖示／價格／餘額。空貨架只有空容器；無 ShopData／無效 ID 需補錯誤文案。買不起／滿槽會靜默拒絕，須補原因。售罄是商品消失；若保留售罄佔位，須另設呈現狀態，不加進庫存。

測連點／過期 action：下架商品的價格 getter 回 0，Action 缺完整庫存檢查，未保證防重購。防重入需同驗 UI／Action；外部金錢變動須刷新狀態。

商店移除／升級尚未接入；[CardRemovalShopButton.tscn](../../../../../game/scenes/ui/shop/CardRemovalShopButton.tscn) 僅佔位 Button／PriceLabel，未被 Overlay 實例化。付費服務須先定義價格、合法牌、取消扣款與限次，再接選牌成功 payload；開啟選牌不等於成交，休息服務也不是交易 API。

Continue 可不買離開；一般返回 Map，幕尾可 generate_next_act，終局發 run_victory。Overlay 到下一個 map_location_selected 才隱藏，Map Back 可能返回商店。須驗退出、重開與 pending 購買互斥。

### 休息服務、選牌及結果

完整休息用途移至 [休息服務畫面](rest-services.md)：包含 RestActionContainer／Continue、auto_end 與成功 child payload、互斥／已用刷新、SELECT opener 返回、零候選／quick pick，以及等待中退出和重入的 fixture。休息不是商店交易 API；內容政策仍由設施規則維護。

現碼 Continue 沒有等待互鎖；換點會清 rest_action_id_to_rest_action_button，晚到 `_on_rest_action_ended(id)` 卻直接索引 dictionary。完整流程要求 location／generation／存在與有效性防護，明列待工程驗收，不宣稱已修。正常 Back 不觸發 child effects 的前提是 min_card_amount=1 且 min_cards_are_required_for_action=true，單設 can_back_out 不足。

### 聲音、動畫與生命週期

設施腳本沒有專屬播放接線；休息選牌演出接 [專屬動畫](../../art-assets/motion/rest-selection.md)，暫選／Confirm／Back 接 [選牌聲音](../../audio/selection-cues.md)。[商店 cue](../../audio/shop-cues.md) 在完成扣款／入庫後播成功聲，拒絕用明確結果；[休息 cue](../../audio/screen-cues.md) 用 rest_action_ended，取消不播成功聲。入庫／服務標記動畫均需新增；關閉停止自建 tween／音訊／timer，await actions_ended 後確認 owner 有效。

### 專項 fixture 與驗收

依 verification 在 autoload ready 後 runtime load 建議的 tests/ui_shop_rest_probe.gd（未建立）。節點／素材檢查接 Smoke Root ready 後；互動另建設施情境，沿 Combat `_scenario()` 起局／固定 seed／map button 模式，配置可達 SHOP→REST_SITE→下一節點，呼叫 Shop.button_up 進商店。新 suite 由 runner owner 接 SUITE_CHOICES（及 ps1 ValidateSet）、分支、mapping、PASS／結果。

ShopData fixture 固定商品及價格並標 shop_is_visited，避免重開隨機重生。分別用 price−1、price、足額／滿槽，記交易前後 money、永久牌組／遺物／消耗品、庫存、按鈕數；售罄、全空、外部金錢改變、重複點擊與 Continue／重開各有斷言。零價 stale action 是待修失敗案例，不作正常預期。

休息專項的成功、Back、等待中換點／run end、同 service ID 重入四條呼叫鏈見 [休息 fixture](rest-services.md#四種-fixture-的具體接法)。原 dictionary lookup 風險保留預期失敗，不能只吞掉信號標通過；所有背景引擎前先排除 [Map 自動焦點](map.md) 等禁用操作，視覺、命中與聽感另列未驗。

## 交接

交付服務 ID／payload、素材顯示框、fixture／caller、資料差值與缺口。依 2026-10-19 固定上游及本地補丁靜態核實；runtime／視覺／輸入／聽感未驗。
