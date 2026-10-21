# 休息服務畫面 — 接受、選牌、完成與返回

[場景目錄](README.md)｜[商店](shop-rest.md)｜[內容規則](../../level-design/noncombat.md)｜[牌庫選取](card-selection.md)｜[驗證接線](../verification.md)

本篇是休息營地完整畫面的單一來源（商店篇只連過來）。

**何時用**：休息服務的完整 UI／音畫呈現，尤其升級／移除開選牌後的確認、Back 及中斷。

**何時不用**：恢復值、互斥或限次規則交內容流程；商店付費服務不能直接套此契約。

## Done when

規格有 rest action ID、opener／location／generation、狀態、Continue 政策、cue 及退出 owner；成功、Back、等待中退出、重入四種 fixture 有 caller 和預期資料差異，適用檢查通過；文件 lint 通過（見 [testing](../../../testing.md)）。以下缺口是待工程驗收，不表示已修復或已播放／渲染驗證。

## 流程

### 入口、畫面包與資料

[Root](../../../../../game/scenes/Root.tscn) 的 RunScreen/RestOverlay 在 REST_SITE 的 map_location_selected 顯示；`ScrollContainer/MarginContainer/RestActionContainer` 是三欄 Grid，ContinueButton 是 sibling。[RestOverlay](../../../../../game/scripts/ui/RestOverlay.gd) 讀 player_available_rest_action_object_ids 建 [RestActionButton](../../../../../game/scripts/ui/RestActionButton.gd)，以 validators／excluded 決定 disabled；缺 ID 略過、空清單仍可 Continue。

玩家應看懂可恢復／升級／移除什麼、是否需選牌、已使用或被其他服務排除的原因。完整素材包是營地背景、服務圖示／名稱／說明、可用／禁用／已用／互斥標記與 Continue 狀態。現有 240×240 RestActionButton 只顯示 rest_action_name，沒有 texture consumer 或 description 欄位；新增圖／說明先定資料來源，再交 [介面素材](../../art-assets/interface-assets.md)，不憑欄位名假設已接。

### 從接受到父畫面完成

以「idle→接受服務→執行中或等待選牌→結果成立→刷新服務→idle」寫規格。handler 只拒絕 actions_being_performed，沒有重新驗 validators／disabled；因此新互動不能只靠灰按鈕阻擋直接呼叫。rest_actions 由 ActionGenerator 產生，auto_end=true 另外排 ActionRestActionEnd；rest_action_ended 才修改 excluded 並重驗按鈕。

INCLUSIVE 排除自身，EXCLUSIVE 排除所有同類，INCLUSIVE_REPEATABLE 不消耗單次；不要從動畫跑完推算次數。auto_end=false 的升級／移除以成功 child payload 執行 REST_ACTION_END。原範例升級可重複、DECK min=max=1、quick_pick=false、can_back_out=true；移除 min=1/max=2。兩者都需 min_cards_are_required_for_action=true，Back 空選才不跑 child，也不更新 rest stat／excluded。

接受選牌服務後，父 RestOverlay 留在底層，CardSelectionOverlay 成為輸入 owner。新增呈現 controller 應鎖父服務與 Continue，記下 opener 的 service ID、location ID、當次 generation；此鎖目前未完整實作。SELECT Back 只是 hide+清 picked+confirmed，沒有導航回休息的函式；因父畫面一直存在，解除鎖後回到同一服務。成功 Confirm 排 child effects 後，父畫面等實際牌組結果與對應 rest_action_ended，再刷新已用／互斥標記，不能在 card_pick_confirmed 或 action_async_finished 當下播「升級完成」。

零候選不足 min 且 required=true 會自動結束無效果；剛好 min 會自動選取，均可能不開 modal。父 controller 因此不能只靠「modal 關閉」解鎖，應依本次 action 完成／取消以及效果結果完成返回。quick pick 也屬自動提交，不能再排第二次 Confirm。

### 取消、Continue 與過期回呼

現有 Continue 沒有選牌互鎖，直接開 Map／run_victory；下一個非休息 map_location_selected 會 clear_rest_actions，清 dictionary 並 queue_free 按鈕。`_on_rest_action_ended(id)` 卻直接讀 `rest_action_id_to_rest_action_button[id]`，可能在換點已清後收到舊完成，造成失效 lookup。現碼也沒有本地 run_ended generation guard；Root／ActionHandler 清 action 不等於這個 UI callback 已安全。

新增 controller 的最小契約是：正常 Back 僅取消這次選牌，保持本 location 的服務；等待期間 Continue 不接受（或由產品另定先取消再離開，不能默默套用）。換 location、player death、run end、離樹均先失效 generation／owner，取消自建 cue，再由現有 action 取消流程解除 await；收到完成時先驗 action／location／generation、dictionary.has(id) 與節點有效性，無效就不刷新、不回開舊營地。這是建議實作及失敗測例，不改既有次數規則。

### 整套聲音與動畫時序

[休息／選牌動畫](../../art-assets/motion/rest-selection.md) 管 RestActionContainer 的視覺 wrapper、接受提示、等待遮罩、服務結果／互斥標記及 Continue 恢復；Grid 管位置，UI 管 excluded／disabled，動畫不得再修改這些遊戲狀態。服務沒有現成揭示／完成序列，第一版可採即時呈現但保留相同 owner 契約。

[畫面音訊](../../audio/screen-cues.md) 管營地環境與服務結果，[選牌 cues](../../audio/selection-cues.md) 管暫選／反選／足額／Confirm／Back。選牌完成不是服務結果；取消不播治療／升級成功聲。退出先停本次 timer／tween／長音，舊完成不能解鎖下一代服務；成功效果已成立時只能停止呈現，不能擅自回滾永久牌組。

### 四種 fixture 的具體接法

建議 tests/ui_rest_services_probe.gd（未建立），由設施情境在真正 REST_SITE map_location_selected、RestOverlay populate 完成後 runtime load；靜態組合另由 Smoke Root ready 後呼叫。設施情境沿 Combat `_scenario()` 起局，但先攔 Map 自動 focus／音訊出口。helper caller await 有界完成並將 assertion 交既有 `_check()`，不是新增檔即被 runner 執行。

成功例提供兩張可升級牌（多於 min）及一張不合法牌，開服務→選合法→Confirm→等待 child idle／rest_action_ended，核對只改該永久牌、統計／excluded 正確且回父畫面。Back 例沿同一 opener，選牌後返回，核對 HP／deck／stat／excluded 不變、父鎖解除且可重開。

退出例在選牌等待及服務結果已排隊但尚未刷新兩個時點，經換 location／run end 清 owner，確認 async 解除、dictionary 已空後舊 rest_action_ended 被拒絕、無錯查／無舊音畫／不重開。這是目前缺少 guard 的預期失敗，不能以忽略 callback 偷改成綠測。重入例同 service ID 但新 generation，故意交付舊 callback，只有新請求能更新；另驗零候選／剛好 min 自動返回、不合法直接 handler、空服務與互斥三種成本型別。

## 交接

交休息 owner、SELECT controller、cue owner 同一請求識別與結果定義；字型／viewport／命中／聽感仍分層驗。既有關卡政策保持單一來源，新增防重與退出保護完成前一律標待實作。
