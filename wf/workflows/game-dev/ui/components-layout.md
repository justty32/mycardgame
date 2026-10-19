# UI 共用元件與版面

[UI 目錄](README.md)｜[互動狀態](interaction-states.md)｜[選單／繁中](menus-localization.md)｜[專項驗證](verification.md)

**何時用**：共用 theme、卡牌／tooltip／按鈕、HUD 資訊層級、容器、長文字、無障礙與不同 viewport。**何時不用**：取消、選取與 Action 時序接互動狀態；圖像生成與裁切接 [素材](../art-assets.md)。

## Done when

本次元件規格存在，列出消費場景、尺寸／字級／樣式來源、資料與互動介面、長文／空值政策及候選 viewport。新增元件的 scene 載入、引用與目標背景斷言回傳預期結果，文件 lint 通過；尚未實測的字形、可讀性與輸入保留待驗。

## 流程

### C：先從既有元件選擇

[Card.tscn](../../../../game/scenes/ui/card/Card.tscn) 是手牌、draft、牌堆、商店與圖鑑共用視圖，根 144×184、圖框 96×96、名稱框 128×16、描述框 128×72。`Pivot/CardVisual` 管呈現，CardButton 管命中，CardGlow／CardDecoratorContainer 管附加狀態。沿 Scenes.CARD 實例化、add_child 之後 init；手牌用 `init(data, 0, true, true)`，牌堆／draft 用 `false, true`，不應把全域戰鬥訂閱套給所有展示卡。改共用尺寸需一併調 Hand.CARD_WIDTH、間距、pivot、曲線、hover 直接位移及重排 tween，並檢查選牌 Grid／HBox。

[KeywordTooltip.tscn](../../../../game/scenes/ui/general/KeywordTooltip.tscn) 是 PanelContainer + RichLabelAutoSizer；KeywordContainer 以 keyword ID 建立多個 tooltip。要顯示一般說明先用 Tooltips.display_tooltip；要顯示資料關鍵字走 KeywordData／KeywordContainer，不複製另一套查表。KeywordTooltip 程式以 BBCode 固定 FONT_SIZE=14 與 image=24，theme 的 12 不一定是最後顯示字級。

[BaseRewardButton.tscn](../../../../game/scenes/ui/rewards/BaseRewardButton.tscn) 及其 Money／Card／Artifact 變體是帶 Action 的領獎元件，適合沿原契約擴充；CardRewardButton 另覆寫為等待選取完成，Skip 保留獎勵；詳 [獎勵流程](screens/rewards-selection.md)。一般確認按鈕不能照搬立即入列的行為。DialogueOption 有自己的 gui_input 與選項契約，也不是通用按鈕控制器。Root 中 overlay 多為內嵌節點，沒有既成通用 modal API。

動態戰鬥元件由 [CustomUIData](../../../../game/data/readonly/modding/CustomUIData.gd) 指向 PackedScene，BaseCombatant.register_custom_ui 加到 `Visible/CustomUIContainer` 再 init。BaseCustomUI 在 combat_ended 請 owner unregister，owner 無效時 queue_free；新元件要驗 owner 死亡、戰鬥結束、移除及重進。這條生命週期不能代替整個 RunScreen modal 的完成契約。

### Theme 的實際責任

[title_screen_theme.tres](../../../../game/themes/title_screen_theme.tres) 是 Theme，Root 多個選單節點直接引用；Button 字級 24、Label 48，定 hover／normal StyleBox，未指定自訂字型。先以 `rg -n 'title_screen_theme|theme_override' game/scenes` 查消費者，局部新需求可做局部 override，共同調整才改共享 theme；不得把它視為全專案預設。

[keyword_tooltip_theme.tres](../../../../game/themes/keyword_tooltip_theme.tres) 供 Root 的 Tooptips、KeywordTooltip、DialogueOption 使用；改 panel 或文字會波及對話選項。[panel_theme.tres](../../../../game/themes/panel_theme.tres) 實際為 StyleBoxFlat，用於 Root、CharacterStat 和 CodexEnemyIntent 的 style override，不能填到需要 Theme 的屬性。Card 另有局部字級、間距和 outline，不會因改 title theme 就統一。

建立新共用規格時，先寫可觀察的 token：主要／次要文字的字型與字級、內外邊距、panel、normal／hover／pressed／disabled／focus 狀態及使用場景。記錄哪些沿引擎 fallback、哪些明確覆寫；只有實際需要共用的值才抽 Theme／theme_type_variation，勿先建立無消費者的完整設計系統。重用 StyleBox 後改值會影響所有引用者，局部差異須用獨立資源或 override，交付列出影響面。

### HUD 資訊優先序與版面責任

未有新視覺規格時，最小提案優先確保本回合決策可讀：手牌費用與描述、能量、敵人意圖／生命／格擋、目前選目標提示和 EndTurnButton。牌堆數量、狀態／遺物及耗材其次；金錢、地圖、暫停作導覽。這是規格提案，不是擅自改動現有位置或規則。tooltip 只補充說明，不能成為唯一的禁止理由或關鍵數值來源。

從 Root 的 RunScreen/Combat 逐層記 anchor、offset、minimum size、size flags、mouse_filter 與 z_index。容器管理子節點時改 margin／separation／size flags，不用任意 offset 抵消 layout。全螢幕遮罩應覆蓋有效區，裝飾層不要攔輸入；HUD 下方需保留 hover 抬牌及 CARD_PICK_Y_OFFSET 的空間。卡牌、按鈕及 tooltip 需同查視覺框與命中框，單改圖像不會擴大 SelectionButton。

CardSelectionOverlay 固定五欄 GridContainer 與 20 間距；draft 用居中 HBox；多數 overlay 背景仍固定 1200×700。不同 viewport 先明定縮放、重排／換欄、最小寬、捲動與安全邊距政策，再改根與子層；1200×700 是目前基準，不是支援清單。候選較小尺寸／不同長寬比要在任務 spec（`games/<game>/design/specs/`）寫出確切數字，不能只說「響應式」。Tooltips 使用 window size 判側，修改 viewport 政策時須一起處理座標系。

### 長文字、字型與無障礙

RichLabelAutoSizer 的 `_min_size=1`，Card 未覆寫；先定最低可讀字級，再依序處理換行、增高／捲動、摘要與完整說明。不截斷規則數值、不將正文烘進卡圖。測最長卡名、升級後名稱、負數／多段數值、X 費用、BBCode 圖示、空描述和多關鍵字；同時核對 locale／enum 字串／tooltip 固定文字，字型與翻譯流程接 menus-localization。

可用／不可用、選中／focus、增益／減益至少保留文字或形狀差異；目前費用紅色、預覽紅綠和 alpha 不是完整無障礙方案。鍵盤焦點要可見、順序可預期，重要說明不能只在 hover 出現；手把接互動狀態。最小字級、對比、目標命中大小及減少動態效果需求以本次產品規格記錄，不宣稱既有螢幕閱讀器或平台無障礙支援。字型 cmap、幾何與背景 property 值都不能證明視覺可讀性。

## 交接

交 scene／script／theme 及全部消費者、規格值、override 原因、長文與 viewport fixture。共享改動用目標斷言檢查多個消費場景；視覺、DPI、控制器及命中證據缺漏明列。核實來源回寫呈現分析，測試接 [verification](verification.md)。
