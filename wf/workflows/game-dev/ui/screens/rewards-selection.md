# 獎勵與選牌畫面 — 領取、挑選與略過

[場景目錄](README.md)｜[牌庫 VIEW／SELECT](card-selection.md)｜[整局規則](../../game-flow.md)｜[專項驗證](../verification.md)

**何時用**：戰鬥／寶箱後整套獎勵畫面與卡牌 draft。**何時不用**：牌堆檢視或效果要求的選牌走 [牌庫 VIEW／SELECT](card-selection.md)；獎勵生成／卡池／跨幕規則走內容及整局流程；戰鬥手牌布局見 [戰鬥](combat.md)。

## Done when

規格有領獎入口、所有獎勵種類／分組、選取／確認／略過／退出結果與素材 cue；fixture 驗領取只一次、選牌結果與持久資料相符、取消不意外入庫，文件 lint 通過（見 [testing](../../../testing.md)）。未完成的確認設計與實際輸入／視覺明列。

## 流程

### 一套畫面要交付什麼

玩家先看懂獲得哪些獎勵、哪些可同取，再挑一張牌或略過，最後回地圖。整套包含獎勵 panel／標題、金錢／遺物／卡牌圖、獎勵列、Card 預覽／tooltip、選取或 focus 狀態、Skip／Continue 文案和空狀態。圖像接 [介面素材](../../art-assets/interface-assets.md)、卡牌接 [卡牌素材](../../art-assets/cards.md)，不能只做一張勝利背景。

[Root](../../../../../game/scenes/Root.tscn) 的 RunScreen 同時有 RewardOverlay、CardDraftSelectionOverlay、CardSelectionOverlay；它們是不同畫面。RewardOverlay 用 RewardContainer/VBox 與 ContinueButton；draft 用 CardContainer/HBox 與 SkipButton，hover handler 是 pass；deck view/select 見牌庫篇。新設計先標 opener 和結束後回哪個父畫面，不只改成一個通用「選牌」panel。

### 入口、正常領取與分組

[RewardOverlay.gd](../../../../../game/scripts/ui/RewardOverlay.gd) 在 combat_started 準備 rewards（reward_grant_requested 只是資料累積，不是已展示或已取得），combat_ended 等 ActionHandler 完成，玩家存活且非通關時顯示；chest_opened 直接 populate。reward_data 建 BaseRewardButton 變體後清暫存資料；按鈕本身保留 action，不能因 dictionary 已清就認為沒有可領獎勵，也不能依已清空 reward_data 推回原選項。沒有寶箱翻牌／逐列揭示。

BaseRewardButton.button_up 把 action 入列後 queue_free，不代表結果已套用；但 CardRewardButton override 會等 action_async_finished，僅 picked_cards 非空才刪除獎勵，所以 Skip 後原按鈕仍可重開 draft。領錢改錢、遺物加入角色，不能把這個基底行為套給卡牌獎勵。選中一個 reward_group 會移除**其他 group**的按鈕，同組可留下多件；產品要改「三選一」須改生成／群組契約，不能只重排 UI。領完／沒有獎勵可留 Continue，但空獎勵文字目前未定義，新增時不要偽造可領項目。

Continue 依 end-of-act／end-of-run 決定下一幕／地圖／勝利；它不是「取消目前 ActionPickCards」。獎勵被其他 modal 遮住時定底層是否可按，禁止同次事件又領獎又離場。死亡／通關／離開 location 的顯示差異沿原 handler，不空發 combat_ended 假造開畫面。

### Draft 與取消

CardRewardButton 帶 ActionPickCards（PICK_DRAFT），其 action_data 含 ACTION_ADD_CARDS_TO_DECK；draft 點牌立即 append picked_cards、發 card_pick_confirmed 並清卡，沒有二次確認；Skip 用空選取完成。兩者都發同一 confirmed，只聽該 signal 無法分辨選中與略過。若要「先高亮、再 Confirm」，須移除點牌立即完成、定義替換選取、零選取與重複確認行為，同時改 draft 狀態、按鈕、一次送出保護與 consumer，讓 Action 恰一次入庫；不能只多一顆 Confirm。

非 Draft 的牌堆 VIEW／效果 SELECT（含 Back、quick pick、自動旁路與取消零效果的設定）見 [牌庫 VIEW／SELECT](card-selection.md)；不同模式不能共享一套「取消就退費」假設。不可選牌要保留原因，長文、多牌、tooltip、鍵盤焦點和多 viewport 接共同 UI；目前無完整控制器支援。離場需釋放等待 action、清舊 card children／timer／tooltip，不能只 visible=false。

### Cue 與進退場

獎勵畫面出現、獎勵接受、資料入庫完成、draft 開始、卡牌選中、Skip、Continue 各自有 owner；skip 不是獲得卡牌，button_up 不是資料已入庫。現有 BaseRewardButton 不提供 cue manager；先查 effect action 中是否已有聲音，避免雙播。音訊接 [畫面聲包](../../audio/screen-cues.md)，進退場／卡牌展開接 [獎勵與地圖動態](../../art-assets/motion/rewards-map.md)。飛向牌組的圖像或粒子不能自己 append 卡牌；不能以 CardTrail 現成推定獎勵已有飛牌。

### Fixture 與驗收

既有 Combat `_claim_rewards()` 驗領錢、開 draft、選第一張後 deck +1／ID 相符。新增專項另驗 skip 不加牌且原獎勵可重開、重複點擊不加兩張、group 保留／排除、全部領完、空獎勵仍能合法離開；Skip 可另設情境，或在 `_claim_rewards()` 第一個 draft 開啟後驗 skip，再透過正式 reward action 提供第二次 draft 驗 claim，明列 fixture 差異。等待 queue idle 再核對持久結果；強制 run end 時驗 action 完成／取消、重進無殘留。一般單場獎勵不證明通關結算。接線與證據層級見 [驗證](../verification.md)。

## 交接

交 reward group／Action／卡池來源、父子畫面返回、素材包、cue 和退出 owner、專項呼叫入口；跨幕與通關交整局 owner，別在 UI 中新增第二套獎勵結算。
