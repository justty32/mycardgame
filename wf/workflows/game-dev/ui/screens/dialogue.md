# 對話事件畫面 — 插圖、文字、選項與分支

[場景目錄](README.md)｜[事件規則](../../level-design/noncombat.md)｜[共同互動](../interaction-states.md)｜[專項驗證](../verification.md)

**何時用**：做一整套角色對話／事件介面，包含圖像、名稱、正文、選項及分支演出。**何時不用**：事件成本／報酬與分支可達性由事件規則決定；純字型處理接 [文字](../menus-localization.md)。

## Done when

畫面規格及素材包有入口、角色／事件身份、每個狀態內容與結果、跳過／取消政策及 cue owner；來源引用和對應分支 fixture 斷言通過。未實作的頭像模型／逐字／配音與未驗視覺、真實輸入明列，文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

### 玩家目的與整套畫面輸入

玩家要讀懂正在發生的事件、辨識說話者、比較選項代價，再做一次決定並看到結果。先取得事件／角色的文字、插圖或頭像、名稱框、正文 panel、選項 normal／disabled／focus 視覺、可用的返回／略過標記；定義無圖、長名稱、長正文與多選項的版面。圖片來源與各框尺寸交 [介面素材](../../art-assets/interface-assets.md)，字型／BBCode 接共同 UI。不要只交一張對話背景圖而缺選項與回饋狀態。

目前 [Root.tscn](../../../../../game/scenes/Root.tscn) 的 `RunScreen/DialogueOverlay` 內有 DialogueNameLabel、DialogueTextureRect、DialoguePromptLabel、DialogueOptionContainer；最後一項逐個建立 [DialogueOption.tscn](../../../../../game/scenes/ui/general/DialogueOption.tscn)。這是一張事件圖＋事件名＋正文＋選項的組合，**不是既成的角色對話系統**：dialogue_name_bbcode 是事件名，state texture 是狀態插圖，沒有 speaker ID、角色姓名／頭像槽或左右說話者自動切換。

若要求角色頭像與逐句對話，最小方案先列 speaker／portrait／text 的資料歸屬與 fallback，再決定擴充 embedded state 或單獨呈現資源；不把事件名冒充角色名。這是需新增的契約，角色表和圖像素材存在也不代表 DialogueOverlay 已消費它。

### 資料與進場路徑

[DialogueOverlay.gd](../../../../../game/scripts/ui/DialogueOverlay.gd) 收 map_location_selected，EVENT 呼叫 start_dialogue；讀當前 EventData.event_dialogue_object_id → DialogueData → initial state，再 populate_dialogue_options 並發 dialogue_started。資料 ID、mod 註冊、成本／報酬 action 與路線可達性都沿事件規則，不在 UI 另造一套。

[DialogueStateData](../../../../../game/data/readonly/embedded/DialogueStateData.gd) 提供 prompt、圖像路徑與 option IDs；[DialogueOptionData](../../../../../game/data/readonly/embedded/DialogueOptionData.gd) 提供選項字串、失敗字串／可見性、validators、actions、next state。Name／Prompt 用 parse_bbcode 一次顯示全文；圖像非空才 FileLoader.load_texture。新狀態空圖路徑會保留前圖，reset 才換 icon.svg；「空值顯示上張、占位或隱藏」必須明定並接線，不能假設已自動清圖。

### 選取、結果、取消與離場

DialogueOption.init 只在建立時驗 validators；失敗依資料隱藏或顯示失敗文字，option_enabled=false 不發點擊。它是 PanelContainer，gui_input 用 left_click **pressed**，和 Card 的 released 不同。有效選項按下即發 dialogue_option_clicked，沒有待確認狀態或確認按鈕；若產品要二次確認，先加選取態與重入鎖，再改 handler，不能同時保留立即執行。

Overlay 以玩家作來源／目標產生 actions，等 actions_ended；玩家死亡則結束，next 空或不存在也結束，合法 next 才重建正文與選項。沒有通用交易回滾或點擊後自動鎖住全部選項；執行中再按、重入以及 await 後已離場須列修正／測試邊界。過期 option_enabled 不會在 handler 自動重驗，動態金錢／生命變更的需求交機制處理。

沒有有效選項會加一顆紅色錯誤離開項，避免卡死；它不是產品的正常「離開」設計。正常取消／返回應由明確無效果、空 next 的 option 表示；現有 UI 無通用 Back、Skip 或 Esc。任務要求略過時須分清「立刻顯示完本句」「跳到下一句」「放棄整段事件」，後兩者不能偷偷跳過成本／報酬或任意發 dialogue_ended。

dialogue_ended、run started／ended、player_killed、離開 EVENT 都 reset：清選項、正文、圖像及 state/data 參照並隱藏。reset 未清 NameLabel（外層隱藏，下次 populate 覆寫），也不取消已提交 actions。action 致死後 await 仍可 end_dialogue，故 dialogue_ended 不是無條件正常成功。Map 的 dialogue_ended consumer 負責後續回地圖；不要再加一條重複的導航。新增待確認、語音或逐字 callback 要有對話 session token／取消旗標，退出後不再更新文字或自動選分支。

### 聲音與動畫 cue 契約

事件進場、完整句顯示、有效選項接受、失敗選項拒絕、效果完成／切 state、正常離開與強制取消各是不同語意。音效綁接受／完成的 owner，不能只用 mouse click 或 money_changed 當選項成功；資料 action 裡已有音效時避免 UI 再播。配音、逐字節奏與跳過停聲交 [對話音訊](../../audio/dialogue-cues.md)，整組演出交 [對話與商店動態](../../art-assets/motion/dialogue-shop.md)。

現碼沒有 visible_characters／逐字 timer、voice ID、語音完成等待或 skip 鍵；它直接 parse_bbcode。新增逐字時規格需說明第一次確認是否只揭全文、第二次才選項、選項何時啟用、快速跳句如何取消舊 timer／音訊。頭像切換、文字揭露、選項出現可共用狀態序列，但動畫完成不得成為漏掉取消時永久卡住的唯一解鎖點。

### 最小專項 fixture 與驗收

先建有效 EVENT／DialogueData、兩個合法 state、一個可選 next、一個 validator 失敗項、一個正常退出項；以真正 location signal 開畫面，不能只手動設 visible。另測零有效選項 fallback、missing initial state、無圖→有圖→空圖、長正文／多選項；missing initial state 目前沒有完整 null guard，不能宣稱安全回退。

依 [驗證接線](../verification.md) 在 autoload／Root ready 後 runtime load dialogue helper，建立有效 run/player/location，再觸發與驗資料／畫面。選一項後 assert action 效果恰一次、next state 和字串／圖像相符，失敗項不變，退出恢復地圖且無剩餘 action；重複輸入、等待中 run 結束和重進不能接到舊 callback。這些為待新增專項，既有 Combat 不涵蓋事件分支。

文字／節點／圖片引用／handler 背景斷言不證明插圖裁切、字形、選項命中、focus 或聲音同步。所有 viewport、語系與視覺／實際輸入缺口列在交付。

## 交接

交事件作者：state／option ID、成本與 next 契約；交美術：整套框與 speaker／插圖區分；交音訊／動畫：語意 cue、完成時點及取消 owner；交測試：fixture、呼叫位置與待驗層級。不要把新角色對話能力寫成既有功能。
