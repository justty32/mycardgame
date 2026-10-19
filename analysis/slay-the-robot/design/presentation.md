# 圖像與 UI 接線核實

[分析入口](../README.md)｜[圖像工作流](../../../wf/workflows/game-dev/art-assets.md)｜[UI 工作流](../../../wf/workflows/game-dev/ui.md)

2026-10-19 靜態查核固定上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 與目前本機檔案。讀取 GDScript、tscn、JSON、PNG IHDR；未啟動 Godot、未操作桌面／視窗，沒有新視覺或真實輸入驗收。下述尺寸是來源檔與 scene 設定，不代表目前螢幕輸出。

## 外部圖像與打包資源是兩條路

[FileLoader.gd](../../../game/autoload/FileLoader.gd) 的 `load_texture()` 先將呼叫參數接到 `_EXTERNAL_FILE_PREFIX`，除錯時是 `res://`，`exported` feature 下是執行檔所在目錄；`is_absolute=true` 才跳過前綴。素材欄位常見值為 `external/sprites/...png`，它不是相對 JSON 或 mod 目錄。外部圖像經 `Image.load_from_file()`→ImageTexture，按完整路徑快取並 take_over_path。缺檔會記錯並回 missing texture；看到占位圖不等於該素材已成功載入。

新增 mod 的圖像可放在 mod 自己的 sprites 子目錄，但資料必須給完整專案相對路徑。mod_info 的 folder map 註冊的是資料 class/table，並不替素材加入相對路徑解析。官方 [example card](../../../game/external/mods/example_mod/cards/card_modded_card.json) 的 `card_texture_path` 為空，不能視為完整的美術接線範例。

scene 的 ext_resource、theme 與預載 intent icons 則屬 `res://` 打包資源。修改 `.import` 不能直接證明外部 ImageTexture 的載入行為改變；同一路徑 cache 也代表改磁碟檔後，既有程序不一定呈現新圖。發行品需帶 external 目錄且設定 `exported` feature，仍須實際成品驗證，現有 Import 證據不涵蓋此項。

## 卡圖尺寸與卡牌排版

讀取 PNG IHDR：`external/sprites/cards/red/card_basic_attack_red.png` 為 96×96、8-bit RGBA。這只證明有 alpha 通道，沒有檢查每個像素是否透明或裁切安全。

[Card.tscn](../../../game/scenes/ui/card/Card.tscn) 的根 Control 最小尺寸與 offset 為 144×184；CardTexture 區域由 `(24,12)` 到 `(120,108)`，即 96×96。描述框 `(8,112)` 到 `(136,184)`，即 128×72；CardName 框為 128×16。EnergySprite 為 32×32。CardButton 是透明、可接左右鍵的 144×184 按鈕；它與圖像節點並非同一物件。

[Hand.gd](../../../game/scripts/ui/Hand.gd) 另定 `CARD_WIDTH=144`、`CARD_SEPERATION_WIDTH=CARD_WIDTH*.75`、pivot 偏移與手牌曲線。只改 Card 場景寬度會使手牌排版仍按舊寬度計算；hover 還有 Card AnimationPlayer 與 Hand tween 兩端要查。現階段沒有用真實滑鼠驗證重疊牌的命中範圍。

[Card.gd](../../../game/scripts/ui/card/Card.gd) 的 `update_card_display()` 延到 process_frame，再載 card_texture_path、名稱／描述、類型與費用。`[energy_icon]` 轉成 width=16 的 BBCode image。RichLabelAutoSizer 會預先透過 FileLoader 載外部 BBCode 圖像並接管路徑；不能把其行為推廣到任意普通 RichTextLabel。

## 角色、敵人、圖示與背景

IHDR 樣本：紅色人物圖 96×96、角色選擇 icon 64×64；藍色敵人 small／medium／large 分別 64×64、96×96、128×128。紅色能量圖為 64×64；內建 attacking intent icon 和 impact_default 第 01 格各 128×128。上述樣本均 8-bit RGBA；這不是全素材盤點或透明像素測試，也不是強制的新素材規格。

[CharacterSelectionButton.gd](../../../game/scripts/ui/CharacterSelectionButton.gd) 消費 `character_icon_texture_path`。CharacterData 雖定義 `character_background_texture_path`，本次在 scripts/autoload 的搜尋未見讀取者；[NewRunMenu.gd](../../../game/scripts/ui/menus/NewRunMenu.gd) 實際更新名稱、描述、HP、金錢與第一個起始遺物。不能只填角色背景欄位就承諾會顯示。

戰鬥角色由 [Player.gd](../../../game/scripts/combatants/Player.gd) 以 character_animation_id 取 AnimationData；敵人由 [Enemy.gd](../../../game/scripts/combatants/Enemy.gd) 以 enemy_animation_id 取得 SpriteFrames。`enemy_texture_path` 消費端是 [CodexEnemiesMenu.gd](../../../game/scripts/ui/codex/CodexEnemiesMenu.gd)，是圖鑑外觀，不能代替戰鬥動畫入口。

[Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn) 的 AnimatedSprite2D 位於 `(99,128)`，其 SelectionButton 範圍為 `(-67,-64)` 到 `(69,64)`；[Player.tscn](../../../game/scenes/combatants/Player.tscn) sprite 位於 `(64,48)`。較大的透明畫布不會自動擴大按鈕命中範圍，血條／名稱又附掛於 sprite 下；換尺寸必須追查這些子節點。

[Combat.gd](../../../game/scripts/ui/Combat.gd) `_update_background()` 依序以非空 Act、Location、Event 背景覆寫，Event 優先。輸出到 BackgroundButton 的 texture_normal，該按鈕也負責互動背景；把它改為純圖層前須追 Hand 的取消／背景按鈕接線。

## 動畫資料與時序

[AnimationData.gd](../../../game/data/readonly/AnimationData.gd) 的實作是 SpriteFrames，頂部 AnimatedTexture 註解已與實作不同。`_animation_data` 支援 frame 路徑陣列、單格 duration、fps、next animation；`regenerate_animations()` 於啟動經 FileLoader 產生並設定 loop。沒有看到 sprite sheet 自動切格流程。

標準人物狀態是 `animation_idle`、`animation_attack`、`animation_death`；VFX 是 `animation_default`。[BaseCombatant.gd](../../../game/scripts/combatants/BaseCombatant.gd) 在 animation_finished 取得 next name，非空則播放下一狀態。VFX 的 animation_offset／隨機 offset 在 [AnimatedCombatEffect.gd](../../../game/scripts/combatants/AnimatedCombatEffect.gd) 消費；不能據此推定一般人物 sprite 也自動套用該 offset。

靜態發現 `add_animation()` 比較 `animation_next_animation_name == animation_next_animation_name`，因此 helper 當下會設 loop=true；`regenerate_animations()` 則正確比較目前名稱與 next 名稱。此任務沒有改遊戲碼或執行重現；未將此獨立疑點宣稱成已驗 bug 修復。素材流程必須查真正載入後的 loop、next 與結束行為，不能只信 helper 註解。

## 字型、文字與互動能力邊界

[project.godot](../../../game/project.godot) 設 1200×700、resizable=false、GL compatibility，只有自訂 left_click／right_click 滑鼠 action。本次檔案搜尋未見 `.ttf`、`.otf`、`.translation`、`.po` 或 `.csv`，project 也未設定翻譯資源；這不排除引擎預設字型，但不能證明繁中 glyph 與語系切換已支援。

[title_screen_theme.tres](../../../game/themes/title_screen_theme.tres) 配按鈕／Label 字級與 StyleBox，未指定自訂字型；`panel_theme.tres` 的實際 resource type 是 StyleBoxFlat。[RichLabelAutoSizer](../../../game/addons/label_font_auto_sizer/rich_label_auto_sizer.gd) 的 `_min_size` 預設為 1，Card 未覆寫，因此防溢位不等於可讀。卡牌類型文字來自 enum keys，描述則來自 CardData；多語工作需同時覆蓋資料與介面固定字串。

Card 的 gui_input 在 action released 時發 selected／right_clicked，mouse_entered 啟動 0.5 秒 keyword timer。Hand 根據狀態決定出牌、選目標或選牌。`Card.init()` 會 connect UI／戰鬥 signals，重複初始化需驗是否重複訂閱；僅 emit signal 的測試不涵蓋實體命中、焦點或控制器導航。

動態 UI 經 [CustomUIData](../../../game/data/readonly/modding/CustomUIData.gd) 的 custom_ui_asset_path→BaseCombatant.register_custom_ui→PackedScene，加入 CustomUIContainer 後 init。[BaseCustomUI](../../../game/scripts/ui/custom/BaseCustomUI.gd) 在 combat_ended 請持有者 unregister，持有者無效時 queue_free；新畫面需保留此退出契約，不能只測建立成功。

## 後續驗證界線

### 主選單與結算的冷接手補查

2026-10-19 同基準靜態追讀：[Root.tscn](../../../game/scenes/Root.tscn) 的主選單位於 `TitleScreen/MainMenu`，由 [MainMenu.gd](../../../game/scripts/ui/menus/MainMenu.gd) 依 save 存在與否切換 Continue／Forfeit／New Run；[BaseMenu](../../../game/scripts/ui/menus/BaseMenu.gd) 綁定匯出 navigation dictionary。修改階層需保留 NodePath 與測試的實際取節點路徑。

結算位於 `RunScreen/RunSummaryOverlay`，附 [RunSummaryOverlay.gd](../../../game/scripts/ui/RunSummaryOverlay.gd)。overlay 及背景固定 1200×700；VictoryLabel／DefeatLabel／EndRunMessageLabel／EndRunButton 使用固定 offsets，統計用 RichLabelAutoSizer。`SUMMARY_TEMPLATE` 將九項統計排成三欄 BBCode，勝利訊息為 `U R WINNER`，敗北讀 `EventData.event_death_message_bbcode`。沒有 current_run_stats 的路徑含 breakpoint，fixture 不能只空發 signal。

`run_victory` 與 `player_death_animation_finished` 設勝敗狀態；EndRunButton 呼叫 Global.end_run。按鈕字串 Back To Main Menu 不足以推論返回位置：[combat_flow.gd](../../../tests/combat_flow.gd) 的敗北分支斷言返回 TitleScreen/NewRunMenu，且硬編 `contains("Damage Taken")` 查統計。翻譯 SUMMARY_TEMPLATE 需要同步這個文案耦合的斷言。該測試的 victory 分支停在一般戰鬥獎勵／回地圖，不涵蓋通關勝利結算。

現有 title_screen_theme 未指定字型，結算另有局部字級；更換主選單 theme 不代表結算或所有 RichTextLabel 都取得相同字型。背景可另建字元涵蓋、實際字型取得及多尺寸 rect 斷言，尚無專項證據。可執行的操作與限制見 [選單、文字與尺寸](../../../wf/workflows/game-dev/ui/menus-localization.md)。

背景可驗圖片解碼、目標資料路徑、SpriteFrames 屬性、scene 實例化與 handler 狀態；尚需依實際改動新增 fixture，現有 Smoke 並不涵蓋任意新畫面。視覺可讀性、alpha 邊緣、動畫美術一致性、不同尺寸與真實輸入均未在本次驗證。工作流已保留後續驗收條件，當前限制下不呼叫 Run、capture 或桌面工具。
