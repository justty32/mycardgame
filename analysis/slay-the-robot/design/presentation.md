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

[Hand.gd](../../../game/scripts/ui/Hand.gd) 另定 `CARD_WIDTH=144`、`CARD_SEPERATION_WIDTH=CARD_WIDTH*.75`、pivot 偏移與手牌曲線。只改 Card 場景寬度會使手牌排版仍按舊寬度計算；Card 場景雖有 hover 動畫資源，Card.gd 未見 play 呼叫；實際 hover 由 Hand 直接改 y／z，重排另用 0.2 秒 tween，兩者不可混稱。現階段沒有用真實滑鼠驗證重疊牌的命中範圍。

[Card.gd](../../../game/scripts/ui/card/Card.gd) 的 `update_card_display()` 延到 process_frame，再載 card_texture_path、名稱／描述、類型與費用。`[energy_icon]` 轉成 width=16 的 BBCode image。RichLabelAutoSizer 會預先透過 FileLoader 載外部 BBCode 圖像並接管路徑；不能把其行為推廣到任意普通 RichTextLabel。

## 角色、敵人、圖示與背景

IHDR 樣本：紅色人物圖 96×96、角色選擇 icon 64×64；藍色敵人 small／medium／large 分別 64×64、96×96、128×128。紅色能量圖為 64×64；內建 attacking intent icon 和 impact_default 第 01 格各 128×128。上述樣本均 8-bit RGBA；這不是全素材盤點或透明像素測試，也不是強制的新素材規格。

[CharacterSelectionButton.gd](../../../game/scripts/ui/CharacterSelectionButton.gd) 消費 `character_icon_texture_path`。CharacterData 雖定義 `character_background_texture_path`，本次在 scripts/autoload 的搜尋未見讀取者；[NewRunMenu.gd](../../../game/scripts/ui/menus/NewRunMenu.gd) 實際更新名稱、描述、HP、金錢與第一個起始遺物。不能只填角色背景欄位就承諾會顯示。

戰鬥角色由 [Player.gd](../../../game/scripts/combatants/Player.gd) 以 character_animation_id 取 AnimationData；敵人由 [Enemy.gd](../../../game/scripts/combatants/Enemy.gd) 以 enemy_animation_id 取得 SpriteFrames。`enemy_texture_path` 消費端是 [CodexEnemiesMenu.gd](../../../game/scripts/ui/codex/CodexEnemiesMenu.gd)，是圖鑑外觀，不能代替戰鬥動畫入口。

[Enemy.tscn](../../../game/scenes/combatants/Enemy.tscn) 的 AnimatedSprite2D 位於 `(99,128)`，其 SelectionButton 範圍為 `(-67,-64)` 到 `(69,64)`；[Player.tscn](../../../game/scenes/combatants/Player.tscn) sprite 位於 `(64,48)`。較大的透明畫布不會自動擴大按鈕命中範圍，血條／名稱又附掛於 sprite 下；換尺寸必須追查這些子節點。

[Combat.gd](../../../game/scripts/ui/Combat.gd) `_update_background()` 依序以非空 Act、Location、Event 背景覆寫，Event 優先。輸出到 BackgroundButton 的 texture_normal，該按鈕也負責互動背景；把它改為純圖層前須追 Hand 的取消／背景按鈕接線。

## 動畫資料與時序

AnimationData 使用 SpriteFrames；人物與 VFX 的狀態、loop／next、offset 消費端及 add_animation helper 的靜態疑點，現由 [動畫核實](animation.md) 與 [VFX 核實](vfx.md) 維護。本頁保留 UI 接線與尺寸事實；不把角色動畫入口和圖鑑 texture 欄位混用。

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


## HUD、選牌與 tooltip 的補查

2026-10-19 本輪讀碼，仍以固定上游加本地 patches 為準，沒有引擎／視覺／真實輸入實測。[Combat.gd](../../../game/scripts/ui/Combat.gd) 位於 Root 的 RunScreen/Combat；EnergyCount 讀 player_data 能量、三個牌堆 Count 讀 HandManager；金錢／生命另接 player_money_changed／player_health_changed。卡牌移動、energy_changed 與 card_queue_refunded 觸發 update_combat_display。EndTurnButton 經 queue_end_turn 和 CombatEndTurn 等待排隊及 actions，Hand disabled 不等同 ActionHandler 忙碌。

[Hand](../../../game/scripts/ui/Hand.gd) 拒絕 disabled、右鍵執行中、不合法牌與同牌已排隊；無目標卡立即入列，需要目標則設 current_selected_card／SelectTargetLabel。Enemy 的 SelectionButton 只在 alive 時發 enemy_clicked，hover／離開發 enemy_hovered(enemy/null) 更新預覽。BackgroundButton 清目標；右鍵先清目標再可能執行 card_right_click_actions，並非純取消。CardGlow 由 validator／選牌使用，不能當成統一可用標記；不合法手牌選取以 alpha=0.3 顯示。

Root 節點實名 `Tooptips`，掛 [Tooltips.gd](../../../game/scripts/ui/Tooltips.gd)；其自身與內容層設 mouse_filter=IGNORE。Card 的 KeywordTimer 0.5 秒後展開，mouse_exited 停 timer 並 hide_tooltip。關鍵字左右擺位用 DisplayServer.window_get_size 和固定 200 餘量，並非 viewport 尺寸，也未做完整底部 clamp。新 viewport／鍵盤 tooltip 需另外接線；現有 mouse signals 不證明 focus 說明可用。

[KeywordContainer](../../../game/scripts/ui/general/KeywordContainer.gd) 取 `card_data.card_keyword_object_ids` 陣列後 append 由 retain／exhaust 等旗標推導的 ID；不是先 duplicate，因此不能宣稱 tooltip 純讀資料。其遞迴 child keyword 展開會避開已存在 ID。這是靜態來源事實，尚未另跑 mutation 重現；修改時應比較展開前後 keyword IDs，不能把新「不變」要求當成既有綠測。

Card.update_card_display 的 `_card_is_rerendering` 會將同 frame 重複請求丟棄，保留第一個呼叫參數；快速換目標需要驗最後預覽。RichLabelAutoSizer 與 KeywordTooltip.fit_content 還有 deferred 更新。背景取文字或 rect 要等實際狀態，不能從方法 return 就推定排版完成。

## 選牌完成、取消與新 modal 的限制

[ActionBasePickCards](../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 根據候選量／min／random_selection 決定自動完成或 card_pick_requested；需要互動才 await 全域 card_pick_confirmed。Hand 接 HAND_PILE，CardSelectionOverlay 接 DECK_PICK_TYPES，CardDraftSelectionOverlay 接 PICK_DRAFT；三者收到 confirmed 都會隱藏／清目前 action，沒有獨立 session ID 或通用 modal stack。

[CardSelectionOverlay](../../../game/scripts/ui/CardSelectionOverlay.gd) 的 VIEW 用 Back 關閉；SELECT 的 Confirm 可見性由 are_enough_cards_picked 決定、Back 由 can_back_out 決定、quick pick 可自動確認。SELECT Back 清空 picked_cards 再發 confirmed，不等於 force_action_end。ActionPickCards 需 min_card_amount≥1 且 min_cards_are_required_for_action=true 才保證零選取不生成子 action；can_back_out 單獨不保證。Draft 點牌即 append 並完成；Skip 空選取完成，沒有第二次確認步驟。

[RewardOverlay](../../../game/scripts/ui/RewardOverlay.gd) 建出帶 Action 的 BaseRewardButton；BaseRewardButton 將 action 入列後 queue_free；CardRewardButton override 等 action_async_finished，僅 picked_cards 非空才釋放，因此 Skip 後原獎勵可重開。卡牌獎勵 ActionPickCards 的子 action 加入持久牌組。`_on_reward_group_selected()` 刪除 reward_group **不同**的按鈕，同組不因此全刪；Continue 走地圖／下一幕／通關，和 draft 完成分開。[combat_flow](../../../tests/combat_flow.gd) 已有領錢及 draft 點牌後 deck +1／ID 對應斷言；沒有 Skip、Back、二次確認與焦點覆蓋。

Root 的兩種選牌 overlay 固定 1200×700、z_index=10、process_mode=1（PAUSABLE）；PauseOverlay 為 3（ALWAYS）。前者分別用五欄 Grid／居中 HBox；follow_focus 存在不等於有完整焦點導航。UI 腳本搜尋未見 ui_cancel／ui_accept、focus_neighbor 或手把事件處理；引擎預設 action 的存在不能證明 Card 的自訂 gui_input 可鍵盤／手把確認。

正常 Back／Skip 與強制 teardown 不同。ActionHandler.clear_all_actions 透過 force_action_end 設 async_cancelled、清 picked_cards、釋放等待；Root._exit_tree 已清 actions／interceptors。只隱藏新增 modal 可能留住等待，需另驗退出／重入，不把 Root 清理推廣成全部 UI 已安全。

## 共用 theme 與後續專項

keyword_tooltip_theme 同時用於 Root Tooptips、KeywordTooltip 與 DialogueOption；panel_theme 為 StyleBoxFlat，Root、CharacterStat 與 CodexEnemyIntent 引用它。Card 有自己的局部 override；KeywordTooltip.gd 又以 BBCode 固定 14 字級／24 圖示。統一 theme 時須查實際消費者和最後取值，不能只改檔名類似的資源。

[元件流程](../../../wf/workflows/game-dev/ui/components-layout.md) 提供 HUD 層級、元件輸入／消費者、最小字級與 viewport 提案；[互動流程](../../../wf/workflows/game-dev/ui/interaction-states.md) 保存確認／取消及輸入契約；[專項驗證](../../../wf/workflows/game-dev/ui/verification.md) 說明 Smoke／Combat helper 的實際接入位置。這些新增 fixture 是待實作方案，runner 仍無 UI suite、自動視覺比對或已驗控制器能力。

## 完整場景用途的新增核實

2026-10-19 追加需求後靜態讀碼。新流程入口為 [UI 場景](../../../wf/workflows/game-dev/ui/screens/README.md)，依玩家用途串接整套組合，而非把元件名當畫面規格；本輪仍未執行 Godot、GUI、音訊或實際輸入。

DialogueOverlay 的 Name 來自 DialogueData 整段事件名，Prompt／Texture 來自 embedded state；不存在 speaker／portrait／逐字／語音／Skip API。非空 state texture 才覆寫，空 path 沿用前圖，reset 才用 icon.svg。DialogueOption 是 PanelContainer，left_click pressed 立即送出；validators 僅 init 時計算，handler 等 actions 後走 next，沒有通用確認／重入鎖。所有選項無效會產生錯誤離開項；missing initial state 沒有完整 null 防護。完整組合及待新增契約見 [對話畫面](../../../wf/workflows/game-dev/ui/screens/dialogue.md)。

BaseMenu 用匯出導航字典，clear_menu 先隱藏，之後可 await 自訂 outro 再 populate 下一頁；intro／outro 預設 null。NewRunMenu 自動選第一角並呼叫 populate_character_info，這條路徑也可播選角音；只顯示第一個起始遺物，沒有角色時無完整空態。SettingsMenu 調整即改 SoundManager，離開導航前存設定，不是 Apply／Discard 模式。RunHistoryMenu 有空歷史及前後索引邊界；CodexCardsMenu 用展示卡而非出牌。來源與完整旅程見 [選單與收藏](../../../wf/workflows/game-dev/ui/screens/menus-collection.md)。

完整戰鬥、商店／休息、獎勵與地圖的畫面規格由場景入口串到既有關卡／整局來源；圖像包、音訊 cue 與動畫時序則連各自用途篇。這些文件提供可實作契約，沒有把角色對話、通用 modal stack、拖放、手把導航、自動視覺比較或新場景 fixture 宣稱為已完成能力。

商店由 Combat/Shop 的 shop_opened 開 ShopOverlay，三類商品入列購買 Action，purchased 後等 actions_ended 再重建；基底價格只在 init 染紅，沒有買不起／滿槽的完整拒絕提示。移除商品 scene 未被 Overlay 建立，RestActionButton 目前只顯示文字，沒有 texture consumer。新服務及取消零效果要依 ActionPickCards 必選條件，完整來源見 [設施畫面](../../../wf/workflows/game-dev/ui/screens/shop-rest.md)。

Map 的 LocationContainer 以資料 position 手排，節點現用共用 icon.svg＋類型文字／???，尚無類型圖映射或連線 renderer。MapLocation 在父層驗 can_travel／鄰接前已標 visited，拒絕點擊仍可能改資料；Map deferred layout callback 會 grab_focus，本輪未執行該路徑。新圖示、拒絕與無焦點 fixture 界線見 [地圖畫面](../../../wf/workflows/game-dev/ui/screens/map.md)。

休息／牌庫 SELECT 復查：RestOverlay.clear_rest_actions 清 dictionary，但 rest_action_ended handler 直接索引 id；換點後舊 callback 可能失效 lookup。CardSelectionOverlay 的 VIEW Back 只 hide，SELECT Back 清選並 confirmed；confirmed／run_ended 也沒有 clear_cards，重建才 queue_free。opener／generation／reason 並非現有欄位，屬新呈現 controller 待實作契約，詳 [休息服務](../../../wf/workflows/game-dev/ui/screens/rest-services.md) 與 [牌庫檢視選取](../../../wf/workflows/game-dev/ui/screens/card-selection.md)。Dialogue reset 不清名稱或取消已提交 actions；致死 action 後仍可能 dialogue_ended，不能把該訊號直接解讀為正常成功 cue。
