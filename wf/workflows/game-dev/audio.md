# audio — 音效、音樂與混音接線

[遊戲開發](README.md)｜[UI](ui.md)｜[內容](content.md)｜[驗收](validation.md)｜[音訊實作核實](../../../analysis/slay-the-robot/design/audio.md)

**何時用**：製作或替換音效、環境音、音樂，調整播放時機、音量、靜音與音樂切換。
**何時不用**：音效所提示的傷害／回合規則交 [mechanics](mechanics.md)；只做素材規格時不先改框架。原生崩潰仍依使用者指示擱置。

## Done when

任務交付檔存在，記有 brief、來源／使用條件、音檔規格、事件接線、版本、驗收命令及未驗範圍；採用素材與引用檔案存在。適用的背景驗證回傳預期結果，文件 strict lint 回傳 0。聽感尚未驗證時，交付檔明列待聽項，不能宣稱完整音訊驗收。

## 流程

### 先定義玩家要聽到什麼

讀 [使用者邊界](../common/user.md) 及上述核實分析，再沿實際呼叫讀碼。先寫一份任務 brief：用途、情緒、辨識優先級、觸發事件／取消條件、預期時長、單次或循環、可否重疊、變體數、目標 bus、音量關係與無聲時的視覺替代。重要資訊不能只靠聲音傳達。

將聲音對應到已確認的遊戲結果；滑過、選中、成功出牌、被拒絕、命中、格擋、死亡是不同事件，避免同一動作在 button 與 action 兩處重複播放。尚無產品方向時保留待定，不替使用者決定主題。設計建議與框架既有能力分開記。

### 取得與整理素材

先盤點既有素材、合法提供的來源與當次可用工具。沒有聲音生成／合成／轉檔工具就記缺口；不要假設 imagegen 能製作音訊，也不為此先安裝服務或建 MCP。生成工具若實際可用，留下工具／模型版本、提示與輸出來源；錄音或委託素材另留製作者、授權範圍、改作及署名要求。框架 MIT 與插件 MIT 不能代替每份外來素材的來源查核。

保留可編輯母檔與遊戲用檔的對應。以穩定語意命名，例如 `sfx_card_confirm_01.wav`、`music_act01_combat_loop.ogg`；路徑用小寫副檔名，變體明確編號，不讓「final2」成為引用契約。多份素材的同質清單超過 1 KB 時，依 [data-files](../common/data-files.md) 保存為 `wf-table/1`，用既有工具讀寫。

建議短且高頻音效先評估 WAV，長音樂評估 Ogg Vorbis；這是 [Godot 4.6 格式取捨](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_audio_samples.html)，不是本專案固定交付規格。記錄實際編碼、採樣率、位元深度、聲道、時長、大小；常見起點是 16-bit PCM、44.1／48 kHz，是否 mono 由用途決定。保留有意義的尾音，裁掉非預期前置靜音；loop 記循環起訖與接縫處理，不能只改副檔名或設 loop=true 就算完成。

記錄峰值與相對響度、同時疊加情境和混音餘量；不把串流平台 LUFS 數字套作遊戲硬標準。匯入 normalize 並不等於混音平衡，短音效與長音樂也不宜只比同一個整體響度數字。無聽音授權時只檢查檔頭、波形／離線量測，留下工具版本與結果，不播放素材。

### 選對載入與播放路徑

目前 `FileLoader.load_audio(path, is_absolute, audio_loops)` 從檔案直接載入小寫 `.wav/.ogg/.mp3`；相對路徑通常從 `external/audio/` 開始，不是相對 JSON 所在資料夾。外部 WAV 的 loop 被程式關閉，OGG／MP3 才接 loop 參數；同一路徑只快取第一次載入的 loop 設定。不要把 Godot 本身支援 WAV loop 誤寫成框架已支援。

外部載入不等同 `load("res://...")` 的匯入資源路徑；不要期待改 `.import` 就會改變這條 runtime loader。打包資源用實際資源引用並保存匯入設定；外部資源在成品需隨 `external/` 複製，且須核對 `exported` feature tag 與成品路徑。未做 export 檢查就保留未驗。

音效可經 `ActionGenerator.generate_sound_action()` 或 `Scripts.ACTION_PLAY_SOUND` 的 `audio_path`／`audio_path_is_absolute` 接入；現實作使用 `play_ui_sound()`，不會等聲音播完才完成 action。循環背景音需採 `SoundManager.play_ambient_sound()` 並安排停止；沒有現成 JSON 環境音 action。

音樂有 TitleScreen、ActData 及 EventData 接點，但事件覆蓋與 action crossfade 有已核實接線缺口，先讀分析再用。需要這兩項能力時補針對性修復與回歸，不以欄位存在當可用。設計切換表，列來源→目的、同曲是否重啟、淡入淡出秒數及離開場景停止條件；目前沒有節拍同步、分層編曲或 ducking 的產品接線。

### 混音、設定與生命週期

目前只有 Master、Music、Sounds；UI／音效／環境音共用 Sounds。新增獨立 UI／環境 bus 時同步選擇、音量控制、設定 schema 與舊設定預設；`override_bus` 名稱不存在會回落 Master，不能把「有聲音」當路由正確。[Godot bus 規則](https://docs.godotengine.org/en/4.6/tutorials/audio/audio_buses.html) 另有說明。

設定目前有三個音量值與背景靜音，離開設定選單才保存；master 透過乘上 music／effects 值實作。讀設定檔成功不代表啟動時已套至 bus。要驗冷啟動、不開設定頁、0／中間值／1、保存後新程序讀回，並區分持久靜音與失焦臨時靜音。禁止切換真實焦點，可在隔離測試直接驗 notification handler；這不證明 OS 焦點事件正確。

重疊音效須寫重複觸發間隔與併發上限需求；現有 pool 會擴張，8 個預建 player 不是限制。驗同 frame 多次觸發、連續切曲、停止／重播與循環離場。`stop()` 不發 `finished`，循環也不會自然完成；回收不可只依該 signal，修清理時接 [resource-lifecycle](resource-lifecycle.md)。

### 分層驗收與交接

先靜態核對檔案、編碼、引用、bus 與事件唯一觸發，再由當次 runtime owner 在隔離副本作無視窗／無實體音訊輸出的背景測試。保留 loader 非 fallback、loop 設定、action 接線、bus 數值、持久化與 pool 回收的斷言及日誌；既有 Smoke 不涵蓋這些音訊專項，需按本次改動補測。

目前禁止桌面、視窗、焦點、截圖、GUI 啟動及干預既有程序；不播放聲音。headless／Dummy 音訊測試只能證明邏輯，不能證明沒有爆音、接縫、遮蔽、延遲或聽覺疲勞。這些寫入交付檔，待使用者另行允許後以同場景混音、不同音量與循環長聽補驗。

## 交接

交付採用素材位置、來源與條件、事件接線、設定相容、已測／待測項；更新受影響分析與 [validation](validation.md)。一般未完工程交 [agent-session](../agent-session.md)，不要把可由 agent 完成的接線工作推給使用者。純文件更新只跑文件檢查，不啟動遊戲。
