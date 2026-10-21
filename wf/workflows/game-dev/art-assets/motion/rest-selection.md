# 休息與牌庫選牌 — 服務、暫選與返回

[共通契約](README.md)｜[休息 UI](../../ui/screens/rest-services.md)｜[選牌 UI](../../ui/screens/card-selection.md)

**何時用**：休息服務、牌庫／牌堆 VIEW／SELECT。

**何時不用**：草稿走 [獎勵](rewards-map.md)，升級結果走 [卡牌](cards.md)。本篇的新增演出與防護均待實作。

## Done when

用途包有素材、根、request 身分、階段與輸入政策，成功／取消／重開專項有日誌；僅規劃明標未實作，觀感與真人操作未驗；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

### 視覺根與素材輸入

[Root.tscn](../../../../../game/scenes/Root.tscn) 的 RunScreen/RestOverlay 使用 ScrollContainer/MarginContainer/RestActionContainer（三欄 Grid）與 ContinueButton；[RestActionButton](../../../../../game/scenes/ui/RestActionButton.tscn) 現為 240×240 文字按鈕。[腳本](../../../../../game/scripts/ui/RestActionButton.gd) 只填名稱，未讀 RestActionData.rest_action_texture_path，也沒有服務說明欄位／Tween／AnimationPlayer。圖示、已用章與鎖定標記須新增節點及消費端，單放素材不生效。

RunScreen/CardSelectionOverlay 使用 ScrollContainer/MarginContainer/CardContainer（五欄 Grid）、CardPickLabel、ConfirmButton、BackButton。[選牌腳本](../../../../../game/scripts/ui/CardSelectionOverlay.gd) 以 init(data,0,false,true) 建 Card，接 UI、不接戰鬥訊號；hover 為 pass，沒有入場序列。素材交尺寸、裁切、安全區、hash。Grid 管布局，新增 wrapper 只動 alpha／scale；CardGlow 由暫選控制，演出不得寫 glow 或永久 CardData。

### 休息：可用→接受→選牌／效果→完成

[RestOverlay](../../../../../game/scripts/ui/RestOverlay.gd) 收 REST_SITE 後重建並 validate 按鈕。先完整顯示服務名稱及可用／disabled 狀態，再開放操作；空服務／全禁用仍提供合法離場。入場短淡入可跳過，輸入不能只靠透明度阻擋。現有 handler 只擋 actions_being_performed，未重驗 disabled／validator；新增 owner 必須在接受點重驗並鎖本服務與 Continue，不能把按下當已完成。

真實資料來源為 [GlobalTestDataGenerator](../../../../../game/autoload/GlobalTestDataGenerator.gd)：rest_action_rest 為 EXCLUSIVE、治療 40%、預設 auto_end=true；RestOverlay 把 RestActionEnd 放陣列首端，ActionHandler pop_back 所以最後執行。rest_action_upgrade_card 為 INCLUSIVE_REPEATABLE、auto_end=false，DECK 選一張 CARD_UPGRADEABLE；rest_action_remove_cards 為 INCLUSIVE、auto_end=false，選一至兩張。兩者 required=true、quick_pick=false、can_back_out=true；成功 child 陣列先列 RestActionEnd 再列升級／移除，執行次序為效果後結束。

新增時序為「接受標記→如有 SELECT 則父畫面保持可見但不可操作→子畫面關閉→等待效果→完成標記→互斥與 validator 刷新→恢復可用輸入」。Back 清空暫選，required 選牌不產生 child，因此上述服務不發 rest_action_ended；返回時取消接受標記，不播放完成章、不耗服務。動畫不得自行補發結束或再做治療／升級。

rest_action_ended 才是服務完成 cue；之後仍等行動收束及資料斷言再解鎖。現碼 INCLUSIVE 排除自身、EXCLUSIVE 排除所有 EXCLUSIVE，REPEATABLE 不排除，再 validate 全部。excluded 只在按鈕實例保存，重建會重設，不能新增動畫記憶宣稱服務使用跨重進持久化。已接受效果不因退場回滾。

### SELECT：候選→暫選→提交／Back

新增 opener 記 location、Action 實例及 generation 再交輸入。card_pick_requested 只讓 DECK_PICK_TYPES 進本畫面，候選到位才 reveal／開輸入。點可選牌加入 picked_cards、亮 CardGlow；再點移除熄燈。max／validator 拒絕不演成選中。數量與 Confirm 依 are_enough_cards_picked，足額提示只在 false→true 播一次。

Confirm 後鎖牌與按鈕，收尾不再發 card_pick_confirmed。現碼 Confirm 沒重驗數量；quick_pick 在點牌 handler 尾端直呼 Confirm，不保證足額或新增了一張，新增 guard 須驗合法及一次提交。Back 清空 picked_cards 再發 confirmed；是否允許只控制可見、handler 未重驗。僅 min≥1 且 required=true 保證空選不排 child，不能把 Back 當普遍 rollback。

[ActionBasePickCards](../../../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 的不足 required、剛好 min、部分非 required、random 分支可直接完成而不開 overlay；零候選依 min／required 分支處理，opener 不得無限等 card_pick_requested。force_action_end 也可能發 confirmed 解除等待。故完成、Back、強制取消須由 request 結果與 generation 區分，不能只聽全域 confirmed 播成功。

[ActionPickCards](../../../../../game/scripts/actions/card_actions/pick_card_actions/ActionPickCards.gd) 生成 child 後就 finish_async_action；這不是升級／移除已完成。返回 opener 時保留提交中狀態，等 actions_ended 且核對效果；休息還驗 rest_action_ended 與相同服務。選牌取消只結束所屬 request，不清除所有無關 actions。現有升級卡面的戰鬥訊號未接此 Grid；成功後由 opener 依結果重建，演出用前後唯讀快照。

### VIEW、退出與聲音

VIEW 展示永久牌庫／抽牌／棄牌／消耗堆，點牌不暫選，Back 通常只 hide；抽牌用洗亂副本，不代表實際順序。進 VIEW 不得沿用 SELECT action；重疊開啟需拒絕或先取消原 request。返回仍存活 opener 並恢復輸入；返回管理尚未實作。

休息 Continue 現直接 show_map 或 run_victory，沒有選牌等待鎖。新演出在等待時禁用 Continue；強制換點／死亡／run_end／離樹仍必須取消自建序列、失效 request、釋放子項並還原輸入。RestOverlay 換點清 dictionary 後，舊 rest_action_ended 仍會直接索引；須新增 location＋generation＋鍵存在與節點有效檢查，不能只 kill Tween。它也沒有本地 run_end／死亡 handler。CardSelectionOverlay run_end 只 hide／清 action、不清卡；新增清理需停卡片提示 timer、撤銷所屬提示與 wrapper，再 queue_free，下一 frame 驗零殘留。

聲音沿 [選牌 cues](../../audio/selection-cues.md) 與 [畫面 cues](../../audio/screen-cues.md)：暫選／反選是 UI 回饋，Confirm 是一次提交，Back／強制退出是取消；服務成功取同身分 rest_action_ended，升級／取得聲取 child 真正結果，不能每層各播一次。減少動態版直接顯示完整候選、靜態選中／已用標記；取消、完成及資料提交次數不變。設定與各 owner 消費仍需新實作。

### 專項接入與交接

依 [背景驗證](../../ui/verification.md)，候選新增 tests/ui_shop_rest_probe.gd、tests/ui_card_selection_probe.gd。caller 選 Smoke._run：Root ready 等兩 frame 後、example mod probe 前 runtime load，await helper.check_scene(game_root)，label/bool 交 _check。helper 建有效 run／player／休息 location，結束還原，不能污染後續探針。helper／caller 目前皆未新增執行。

休息 fixture 覆蓋三種 cost type、多於 min 的可升級牌、不可升級牌與可移除牌；真實按鈕→ActionPickCards→Confirm／Back，驗 HP／永久牌組／升級／stat／excluded 差及 cue 次數。選牌 fixture 驗不足／足額／反選／max、Confirm、Back 允許及禁止、quick_pick、零候選及恰 min、四種 VIEW 零資料變更。兩者另驗等待時換點／run_end、重開第二次只完成一次、減少動態；以有界 action idle／狀態等待而非任意 sleep，記 stale callback=0。

背景啟動前須在候選攔截聲音及 Map.show_map 焦點副作用；headless 不等於無聲／無焦點，攔截前不啟動引擎。下一 agent 交接素材、根、opener token、cue owner、取消結果、命令／斷言日誌與未驗項，再請獨立復走。
