# 美術方向與靜態資產的製作接點

[設計分析入口](README.md)｜[呈現架構](presentation.md)｜[美術流程](../../../wf/workflows/game-dev/art-assets.md)

2026-10-19 以來源鎖 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本機既有修復靜態核實。讀 GDScript／tscn 與四個 PNG 標頭，沒有生成素材、完整解碼像素、啟動 Godot 或操作桌面／UI／截圖；也沒有視覺風格評分。以下是使用端事實與能力邊界，操作契約在工作流。

## 卡圖：畫布不等於完整卡牌

[CardData](../../../game/data/prototype/CardData.gd) 位於 prototype 而非 readonly，`card_texture_path` 與名稱／描述分欄。[Card.gd](../../../game/scripts/ui/card/Card.gd) 的 update_card_display 等待 process_frame 後呼叫 FileLoader，並個別更新文字與能量圖示。故只驗資料 path 不足以證明場景已刷新，圖片也不應包含動態卡名／數值。

[Card.tscn](../../../game/scenes/ui/card/Card.tscn) 的 CardTexture 是 96×96；CardName 是它的子節點，offset_top=-4、bottom=12，會佔用圖像上緣附近。整張牌的 144×184 還包括名稱、費用及描述。PNG `external/sprites/cards/red/card_basic_attack_red.png` 的 IHDR 為 96×96、8-bit、color type 6（RGBA）；這不是全透明背景或裁切安全的像素證據。其他排版與 Hand 的耦合見呈現架構。

## 角色圖：頭像、戰鬥與未接線立繪

[CharacterSelectionButton](../../../game/scripts/ui/CharacterSelectionButton.gd) 在 init 讀取角色的 `character_icon_texture_path`，非空才設 texture_normal。[CharacterData](../../../game/data/readonly/CharacterData.gd) 同時宣告 `character_background_texture_path`，但本次搜尋 scripts／autoload 沒找到其讀取者；[NewRunMenu](../../../game/scripts/ui/menus/NewRunMenu.gd) 的已讀顯示更新是角色文字／數值及起始遺物圖。新增一張選角頁立繪需要 UI 消費端，不能由欄位存在推論已支援。

[Player](../../../game/scripts/combatants/Player.gd) 與 [Enemy](../../../game/scripts/combatants/Enemy.gd) 的戰鬥 SpriteFrames 來自 animation ID；[CodexEnemiesMenu](../../../game/scripts/ui/codex/CodexEnemiesMenu.gd) 才讀 enemy_texture_path。角色紅色樣本 `character_red.png` 是 96×96，`character_red_icon.png` 是 64×64，均由 IHDR 判為 8-bit RGBA。這些是既有占位素材尺寸，沒有替原創方向選定畫風或保證立繪縮成頭像後可讀。

## 圖示：同一檔案的多個使用尺寸

[ColorData](../../../game/data/readonly/ColorData.gd) 定義能量圖路徑，Card 的費用圖、描述 `[energy_icon]` 替換及 [Combat](../../../game/scripts/ui/Combat.gd) 的能量區分別消費它。紅色能量 PNG 的 IHDR 是 64×64 RGBA；Card 能量框是 32×32，描述內嵌圖寬 16。來源大圖成功不代表最小使用尺寸已通過。

[StatusEffectData](../../../game/data/readonly/StatusEffectData.gd) 的 get_status_effect_texture_path 於 charges<0 且 negative path 非空時回負值圖，否則回一般圖。[StatusEffect](../../../game/scripts/combatants/StatusEffect.gd) 依此載 texture，數字與 visibility 分別更新；[KeywordTooltip](../../../game/scripts/ui/general/KeywordTooltip.gd) 則引用一般 texture path。負層數變體不能推定 tooltip 也會自動使用。

Enemy 的 INTENT_DISPLAY_TYPE_TO_INTENT 實際映射到五個 TextureRect 節點，圖片資源在 [Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn)；不是任意資料 texture path 的通用圖示載入器。改意圖圖要查 scene；改意圖類型還要查映射與資料 enum。此任務未更改這些接點。

## 背景覆寫與空值

Combat._update_background 先採非空 Act，再採非空 Location，最後採該地點非空 Event 的背景。只有最後路徑非空才設 BackgroundButton.texture_normal；全部空白的分支沒有清空既有 texture。靜態推論：同一場景內由有圖地點切往全空地點可能保留前圖；尚未 runtime 重現，因此列為專項情境，未宣稱已修復 bug。

BackgroundButton 仍承擔背景互動，不能把換圖等同任意改節點型別。主選單背景不是此函式的消費端。新背景應由需求指定實際容器與裁切契約，不從 project viewport 推論所有背景母稿必須相同尺寸。

## 外部檔案與版本證據

[FileLoader](../../../game/autoload/FileLoader.gd) 的 load_texture 對完整路徑快取；非 absolute 參數會接除錯的 res:// 或 exported feature 的 exe 目錄前綴。存在檔案經 Image.load_from_file→ImageTexture，缺檔回 MISSING_TEXTURE；檔案存在但無效的路徑不能只靠「不是 missing」判成功，還須核對實際 texture 尺寸與解碼結果。外部欄位的路徑不是相對 JSON。

[example card](../../../game/external/mods/example_mod/cards/card_modded_card.json) 的圖路徑空白，因此不能當成完整素材整合範例。scene ext_resource 與外部 ImageTexture 的機制不同；只改 .import 或重用既有程序的 cache 不提供可靠替換證據。匯出時 external 搬移與 feature tag 尚需成品驗證。

## 製作能力與未驗範圍

現有原始碼沒有定義原創美術方向、跨類別風格版本、母稿派生清單或批次美術評分器；這些是任務工作流要保存的製作知識，不是新增遊戲 schema。當前會話提供圖像生成工具／skill 入口，不代表此專案已跑過生成、去背、批次一致性或動畫製作。本次未呼叫它們；也未查網路素材授權或把外部研究參考的素材匯入專案。

目前證據足以指出檔案及消費端，不能證明透明像素、色彩、光源、縮圖辨識、人物一致性、背景對比、真實互動或匯出品質。來源／引用檢查、引擎接線檢查與視覺定版需分別留證；未具備工具或授權的階段直接寫未驗。可執行流程見 [風格方向](../../../wf/workflows/game-dev/art-assets/style-guide.md) 與 [靜態素材](../../../wf/workflows/game-dev/art-assets/static-assets.md)。

## 卡框裝飾與未實作卡背

2026-10-19 因用途導向任務補查。Card.tscn 的 ColorBackground 是 144×184 ColorRect，Background 在內縮 4 像素的矩形；Card.gd 以 ColorData.color 設外框顏色。CardType 文字由 rarity enum key 與 type enum key 串成，沒有在此路徑讀稀有度框圖。CardGlow 為額外 ColorRect，set_card_glow／_attempt_hand_glow 控制顯隱；能量不足調整費用文字顏色，hover 另有 Card 動畫和 Hand 行為。這些現成狀態不等於各自有可替換圖片欄位。

[CardDecorator.tscn](../../../game/scenes/ui/card/CardDecorator.tscn) 最小 24×24，中央 CardDecoratorValueLabel 也是 24×24。[CardDecorator.gd](../../../game/scripts/ui/card/CardDecorator.gd) 依 [CardDecoratorData](../../../game/data/readonly/CardDecoratorData.gd) 載外觀及行為腳本；texture path 非空才顯示，label value name 則取 card_values。Card.gd 僅在 decorator script path 非空時建立該 UI，裝飾圖不是一個與邏輯完全無關的通用 skin 欄位。

本次以 card_back／back_texture／back_sprite／card_front／face_down／face_up 在 game/data、scripts、scenes 搜尋無匹配，並讀 Card／Hand 接線；未找到單卡背面顯示或翻面契約。這是搜尋範圍內的能力缺口，未宣稱已驗所有插件。新的框皮膚、稀有度圖片與卡背需實作各自 consumer；製作流程不得虛構既有欄位。

[CardShopButton.tscn](../../../game/scenes/ui/shop/CardShopButton.tscn) 重用 Card，容器最小 144×208；PriceLabel 起於 y=184，與卡牌圖像分層。框尺寸改動會影響這個使用者，並非只改手牌。

## 戰鬥人物與頭目共用的容器

[EnemyData](../../../game/data/prototype/EnemyData.gd) 有 STANDARD／MINIBOSS／BOSS 類型，但 [EnemyContainer](../../../game/scripts/ui/EnemyContainer.gd) 的 _spawn_enemy 都以 Scenes.ENEMY 建實例，填入原型資料；此路徑沒有按 boss 類型換專用場景或尺寸。事件可採自動 HBoxContainer 或 event_enemy_placement_positions 的定位 slots，大體型素材須查該事件容器與鄰近單位。

[Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn) 根 minimum size 200×144，offset 高 192；sprite 位於 `(99,128)`。 [Player.tscn](../../../game/scenes/combatants/Player.tscn) 根 minimum size 200×144，sprite 位於 `(64,48)`。兩者血條與 SelectionButton 都在 sprite 下，不能以替換 PNG 畫布推導 hit rect 自動擴大。Enemy 名稱及意圖亦有各自位置，圖像母稿需配合完整容器。

[CharacterSelectionButton.tscn](../../../game/scenes/ui/CharacterSelectionButton.tscn) minimum size 64×64，toggle_mode=true，設 texture_normal 且 ignore_texture_size=true。資料只載 normal 圖；選取／hover 的獨立圖片需要新接線或 theme 規格，不是 character_icon_texture_path 自動派生。

## 介面圖片與程式樣式的界線

[Root.tscn](../../../game/scenes/Root.tscn) 中 DialogueOverlay 是 1200×700，DialogueTextureRect 從 `(88,144)` 至 `(544,600)`，即 456×456。[DialogueOverlay.gd](../../../game/scripts/ui/DialogueOverlay.gd) 以 current_dialogue_state.dialogue_state_dialogue_texture_path 更新這個單一插圖節點，僅非空才覆寫；reset_dialogue 會另重設 icon.svg，clear_dialogue_options 本身只清按鈕。這個接點是狀態插圖，沒有在已讀路徑分出 speaker portrait 或表情控制。連續狀態的空圖行為要依更新／清理時點實測，不可只靠欄位存在推論會清圖。

[DialogueOption.tscn](../../../game/scenes/ui/general/DialogueOption.tscn) 是 PanelContainer + RichTextLabel，minimum width 240，採 keyword_tooltip_theme；不是內建三張選項按鈕圖。對話的可選／禁用輸入機制與視覺狀態仍由 UI workflow 追實碼。

商店的 [ArtifactShopButton](../../../game/scripts/ui/shop/ArtifactShopButton.gd) 和 [ConsumableShopButton](../../../game/scripts/ui/shop/ConsumableShopButton.gd) 將資料圖填到 Button.icon；[BaseShopButton](../../../game/scripts/ui/shop/BaseShopButton.gd) 以獨立 PriceLabel 顯示價錢，缺錢設紅色。[RestActionButton](../../../game/scripts/ui/RestActionButton.gd) 讀 rest_action_name 給 Button.text，已讀檔沒有 rest action 圖示載入。

獎勵的 [ArtifactRewardButton](../../../game/scripts/ui/rewards/ArtifactRewardButton.gd) 載 artifact_texture_path；[MoneyRewardButton](../../../game/scripts/ui/rewards/MoneyRewardButton.gd) 和 [CardRewardButton](../../../game/scripts/ui/rewards/CardRewardButton.gd) 主要設文字，CardRewardButton 點選後等待選牌 Action 完成。不能從卡牌獎勵名稱推論該按鈕已顯示獎勵卡圖。

[MapLocation.tscn](../../../game/scenes/ui/MapLocation.tscn) 為 64×64 TextureButton、icon.svg normal 圖，下方另有 MapLabel；[MapLocation.gd](../../../game/scripts/ui/MapLocation.gd) 設位置並用類型 enum 名稱或 ??? 作文字。[Map.gd](../../../game/scripts/ui/Map.gd) 略過 STARTING、建立地點並對可走節點啟動 flash_map_location。該動畫改 self_modulate；已讀流程沒有按每種節點類型選圖，也沒有現成可交路線圖材質的接線證據。

[title_screen_theme](../../../game/themes/title_screen_theme.tres) 以 StyleBoxFlat 定義 normal／hover，另有 icon focus／hover_pressed 色與字級。Root/TitleScreen/Background 為 ColorRect；標題為 Label。圖像 Logo、九宮面板、texture buttons 是可提出的設計方案，非現成可任填資料圖片的介面。需求如採 atlas／切片，須新增正確 scene 資源接法；外部 load_texture 只載圖，不自動分片。

## 場景背景幾何與前後層

Root/RunScreen/Combat 是 1200×700。其 Background 為全區 ColorRect、Background2 為頂部 1200×64 色塊；BackgroundButton 是滿 anchor 的 TextureButton，button_mask=3、ignore_texture_size=true、stretch_mode=0。節點先後不代表可把新增前景任意插入，改動時須查各層 z／mouse_filter 及背景取消選牌接線。

現有 Player 容器 rect 為 `(200,336)` 至 `(400,480)`；EnemyContainer 是 `(568,256)` 至 `(1176,448)`；Hand 是 `(168,632)` 至 `(1048,692)`。它們的 sprite、血條與 hover 可超出這些根 rect，因此只能作安全區設計起點，不能當最終動畫可見範圍。

ShopOverlay／RestOverlay／DialogueOverlay／RewardOverlay 各自有背景與 z_index=10，Map 的 z_index=100；替換 Act 背景不等於替換這些 overlay 裝飾。TitleScreen 背景另屬 scene ColorRect。已讀 Combat 背景路徑只有單一 texture_normal，沒有通用前景／視差 layer data；多層環境與視差須當作新接線需求。

本次追加只讀以上 source，未製作圖片、未生成切片／圖集、未啟動引擎或驗畫面。用途流程在 [卡牌](../../../wf/workflows/game-dev/art-assets/cards.md)、[戰鬥人物](../../../wf/workflows/game-dev/art-assets/combatants.md)、[介面素材](../../../wf/workflows/game-dev/art-assets/interface-assets.md) 與 [環境](../../../wf/workflows/game-dev/art-assets/environments.md)；共通製作沿原 style-guide／static-assets，避免以用途拆分複製版本資料。
