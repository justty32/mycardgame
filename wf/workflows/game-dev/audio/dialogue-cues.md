# dialogue-cues — 頭像、文字、選項與分支的聲音流程

[聲音場景入口](README.md)｜[對話 UI](../ui/screens/dialogue.md)｜[場景編排](../art-assets/scene-choreography.md)

**何時用**：為一個有圖像、文字、選項與分支的對話場景建立整組聲音與取消行為。
**何時不用**：只換事件插圖回美術流程；未要求配音時，不擅自增加角色語音或逐字系統。

## Done when

對話聲包與 state／option 對應紀錄存在，含進場、閱讀、選項、分支、關閉及中斷規格；逐字／語音採用或不採用有明確決定。專屬 fixture 有成功、禁用、分支等待、死亡／離場及快速輸入的播放計數證據；未執行項標明。

## 流程

### 先組聲包並對準現有資料

聲包可包含事件進場短音、可選環境循環、閱讀期間的稀疏文字音或語音、選項確認／拒絕、分支轉場及結束短音。語音與文字音預設互斥，除非 brief 有理由；圖像切換不必額外發聲。逐項記時長、尾音、可跳過、重播、音量、變體／冷卻及有無 loop，沿 README 保存來源和素材規格。語音另記語言、speaker／line ID、字幕全文及音檔對應，不靠檔名猜台詞。

目前 [DialogueOverlay](../../../../game/scripts/ui/DialogueOverlay.gd) 讀 DialogueData／DialogueStateData，直接 `parse_bbcode()` 顯示名稱與 prompt，圖像是 state 的 dialogue texture，不是已建立的 speaker portrait 系統。**沒有逐字顯示、語音播放、字元到達或台詞完成事件**；新增這些須同時改 UI state／資料 schema／音訊 owner 與測試，不能只填不存在的 audio 欄位。若本次只做既有能力，閱讀階段可以保持無聲。

### 進入、閱讀與分支的 owner

`start_dialogue()` 先 reset、解析初始 state 並 populate，成功才發 dialogue_started。將進場短音綁成功狀態，而不是每次 `populate_dialogue_options()`；後者也在分支轉換使用。地點 music 已有共用 owner，對話只能提供事件曲選擇／環境層政策，不另搶一條重複配樂。

每段閱讀以 dialogue ID＋state ID＋generation 為播放識別；同 state 重繪不重啟台詞，真正重新進入是否重播由 brief 決定。新增逐字時，UI owner 發「可見字元進展」或有界節奏事件；排除 BBCode 標記、空白及非顯示字元，快速顯示全文時取消剩餘字音，不能一口氣補播。語音則由聲音 owner 保存 stream handle，UI 字幕可獨立讀完；實際台詞完成回呼必須檢查 generation，舊台詞不能推進新分支。

[DialogueOption](../../../../game/scripts/ui/general/DialogueOption.gd) 只有 option_enabled 且 left_click 時 emit dialogue_option_clicked；禁用選項沒有 click 事件，因此現有該 signal 不能提供「點了禁用選項」拒絕音。若有此需求，由 UI 輸入邊界新增明確拒絕通知並保留 failed-validator 文字，不能繞過 validator 來播確認。

Overlay 收到選項先建立 actions、等待 actions_ended，檢查玩家生死後才換下一 state 或結束。選項短音代表「接受選擇」；分支到達短音代表「效果完成並進新 state」，兩者要不同且有必要才保留。await 期間的多次點選目前沒有專用音訊去重契約，須以 option transaction ID／輸入鎖防止重複請求；不能只靠聲音冷卻遮住重複 action。

### 關閉與中斷

end_dialogue 發 dialogue_ended，但選項 actions 致死後，await 回來也會呼叫 end_dialogue；該 signal 不等於正常成功。reset 另由 run_started／run_ended／player_killed／非 EVENT 節點觸發。聲音 owner 須核對存活、有效 generation 與結束原因；目前沒有 cause payload，若需區分須由 owner 新增。只有正常有效關閉播一次收尾；死亡／離場取消台詞、字音排程及非保留循環，零成功收尾音。

新 state、跳過、快速選項、對話被其他頁覆蓋、死亡、離樹都要撤銷舊 generation；停止時同時處理 player、tween 與延後回呼。語音淡出長度與選項可否立即接受在 brief 明列，不等待音訊完成才解除必要遊戲輸入。無聲時保留台詞全文、說話者辨識（若實作）、選中狀態、禁用原因與分支結果，不讓音訊成為唯一進度訊號。

### 測試接法

沿 [mixing](mixing.md) 的無聲門檻，在既有 Smoke 的 Root 建立後、example mod probe 前呼叫專屬對話 helper；需要旅行資料時建立固定 EventData／DialogueData fixture，走實際 start／option handler。新 helper 不會自動執行，須納入 `_check()` 並保留 SMOKE PASS。這是未執行橋接，不是已有 Dialogue 或 Audio suite。

fixture 至少含兩個 state、有效／禁用選項、延後 action 與結束分支。斷言進場一次、populate 重繪零新增進場音、有效選擇一次、禁用零確認、actions 尚未完成不播下一 state、死亡／run 結束取消 pending cue、再開新對話無舊回呼。新增逐字／語音時再驗立即顯示全文不補播、連按 skip、語言切換、無音檔 fallback 與字幕仍可完成；loader 通過不代表這些功能通過。

## 交接

將 state／option ID、文字可見／選擇／分支完成／取消的語意契約交 UI 與動畫 owner；只連已實作事件。bus、持久音量及語音是否需獨立 bus 交 [mixing](mixing.md)，不預設現有 Music／Sounds 已提供 Voice。
