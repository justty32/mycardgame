# dialogue-cues — 頭像、文字、選項與分支的聲音流程

[聲音場景入口](../audio.md)｜[對話 UI](../ui/screens/dialogue.md)｜[場景編排](../art-assets/motion/README.md)

**何時用**：為一個有圖像、文字、選項與分支的對話場景建立整組聲音與取消行為。
**何時不用**：只換事件插圖回美術流程；未要求配音時，不擅自增加角色語音或逐字系統。

## Done when

對話聲包與 state／option 對應紀錄存在，含進場、閱讀、選項、分支、關閉及中斷規格；逐字／語音採用或不採用有明確決定。專屬 fixture 有成功、禁用、分支等待、死亡／離場及快速輸入的播放計數證據；未執行項標明。

## 流程

DialogueOverlay 的進場、選項、actions 等待、reset 與 dialogue_ended 鏈，以及「沒有逐字／語音／speaker 系統」的現況，以 [對話畫面](../ui/screens/dialogue.md) 為準；本檔只寫聲音的時點、owner 與取消。共同去重與取消規則見 [audio 入口](../audio.md#場景聲包共同規則)。

### 聲包

聲包可包含事件進場短音、可選環境循環、閱讀期間的稀疏文字音或語音、選項確認／拒絕、分支轉場及結束短音。語音與文字音預設互斥，除非 brief 有理由；圖像切換不必額外發聲。另記可跳過與重播政策。語音另記語言、speaker／line ID、字幕全文及音檔對應，不靠檔名猜台詞。只做既有能力時，閱讀階段可以保持無聲；新增逐字或語音不能只填不存在的 audio 欄位。

### 進入、閱讀與分支的 owner

進場短音綁 dialogue_started，而不是在分支轉換也會呼叫的 `populate_dialogue_options()`。地點 music 已有共用 owner，對話只提供事件曲選擇／環境層政策，不另搶一條配樂。

每段閱讀以 dialogue ID＋state ID＋generation 為播放識別；同 state 重繪不重啟台詞，真正重新進入是否重播由 brief 決定。新增逐字時，UI owner 發「可見字元進展」或有界節奏事件；排除 BBCode 標記、空白及非顯示字元，快速顯示全文時取消剩餘字音，不能一口氣補播。語音則由聲音 owner 保存 stream handle，UI 字幕可獨立讀完；實際台詞完成回呼必須檢查 generation，舊台詞不能推進新分支。

禁用選項不發點擊 signal；需要拒絕音時由 UI 輸入邊界新增明確拒絕通知並保留 failed-validator 文字，不能繞過 validator 來播確認。

選項短音代表「接受選擇」；分支到達短音代表「actions 完成並進新 state」，兩者要不同且有必要才保留。await 期間的多次點選須以 option transaction ID／輸入鎖防止重複請求。

### 關閉與中斷

dialogue_ended 在選項致死後也會發，且目前沒有 cause payload；若需區分正常關閉，由 owner 新增原因並核對存活與 generation。只有正常有效關閉播一次收尾；死亡／離場取消台詞、字音排程及非保留循環，零成功收尾音。

新 state、跳過、快速選項與對話被其他頁覆蓋也要撤銷舊 generation，同時處理 player、tween 與延後回呼。語音淡出長度與選項可否立即接受在 brief 明列，不等待音訊完成才解除必要遊戲輸入。無聲時保留台詞全文、說話者辨識（若實作）、選中狀態、禁用原因與分支結果，不讓音訊成為唯一進度訊號。

### 測試接法

專屬 helper 的 caller 與 EventData／DialogueData fixture 沿 [對話畫面](../ui/screens/dialogue.md#最小專項-fixture-與驗收)，走實際 start／option handler。fixture 至少含兩個 state、有效／禁用選項、延後 action 與結束分支。斷言進場一次、populate 重繪零新增進場音、有效選擇一次、禁用零確認、actions 尚未完成不播下一 state、死亡／run 結束取消 pending cue、再開新對話無舊回呼。新增逐字／語音時再驗立即顯示全文不補播、連按 skip、語言切換、無音檔 fallback 與字幕仍可完成；loader 通過不代表這些功能通過。

## 交接

將 state／option ID、文字可見／選擇／分支完成／取消的語意契約交 UI 與動畫 owner；只連已實作事件。bus、持久音量及語音是否需獨立 bus 交 [mixing](mixing.md)，不預設現有 Music／Sounds 已提供 Voice。
