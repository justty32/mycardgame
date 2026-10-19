# 世界與整局冷啟動復走

2026-10-19。受測者由無先前對話歷史的子 agent 接手；只從 wf/WORKFLOWS.md 出發，不讀其他報告或 onboarding 結果表。讀過 agent-session 指定的根入口、STRUCTURE、WORKFLOWS、INDEX、PROJECT、模板、common 入口／user／conventions／code-map／data-files、learning，並按入口補讀 dev-env、feature-dev、testing、validation。開場條目計數只在 SESSION-LOG 得到一筆，已讀；WAIT_USER 無匹配。

本機 game HEAD 為 4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d，來源鎖列 framework-fixes 與 resource-lifecycle 補丁。唯讀 git status 顯示 13 個遊戲檔既有修改，本次不改動。只做文件與靜態 source/tests 核對；未執行 Godot、未操作桌面／UI／聲音或既有程序、未 commit/push。本檔是唯一寫入檔。

## 初讀與中斷

WORKFLOWS → agent-session → game-dev 分流至 level-design 的 combat／noncombat／map-act，以及 game-flow 的 vertical-slice／persistence。各篇連到內容 bootstrap、領域分析及明確 source/tests，無須全 repo 搜尋。額外 rg 僅在已指到的 source/tests 查函式、ID、欄位和 runner suite。

首次讀取 `analysis/slay-the-robot/design/noncombat.md` 時檔案不存在，Get-Content 回傳 exit 1。這是 noncombat 工作流的「核實來源」斷鏈，不能記為順利通過。已即時告知協調者；協調者確認當時文件 owner 尚未收尾，要求 A/B 暫停，文件 freeze 後再讀。此首次 blocked 記錄保留，不以後續成功覆寫。缺分析不代表 source 完全不可達：noncombat 同頁仍直接指向 schema、DialogueOverlay、ShopOverlay、RestOverlay 與 ActionOpenChest。

## C：第一個原創可玩版本

路由是 game-dev → game-flow → vertical-slice／persistence → design/game-flow，另沿 content／bootstrap 建內容、level-design 接節點、testing 接驗證。C 本身可以提出可執行計畫；產品玩法尚未定義是明示未決條件，不是導航缺口。

第一個應寫的是任務規格與計畫（落點 design/specs、design/plans，由 planning 指引），明定角色、核心決策、局長、兩幕以上、節點、最終 Boss 是否直接結算、checkpoint 及局外保留。第一批遊戲檔是 `game/external/mods/mycardgame/mod_info.json`、角色／玩家 JSON 與 mod_list 登記。候選識別字可為 `character_original`、`player_original`，只是工程佔位，不表示題材已決。CharacterData.character_player_id 對 PlayerData prototype，PlayerData.player_character_object_id 回指角色；新起手卡與獎勵卡包分開接。

Global.gd:208 的 start_run 會重建玩家、牌組／遺物／卡包／HP／金錢、seed 與 stats；:244 固定 location_0，:279 固定 generate_act("act_1", true)。因此現有內容方案可明確 patch act_1 與它的 next IDs；若要求角色自選起始幕，第一個框架改點是 Global.start_run 並增設明確資料契約，不能把未知欄位塞進角色 JSON。兩幕例需同時設定 PlayerData.player_act_max=2 及 act_1 → 新第二幕；不是只讓最後 act_next_act_ids 為空。

開發順序先做角色設定→NewRunMenu start handler→起點選擇→Map 可旅行→相鄰戰鬥→領獎返回，另做真傷害敗北→摘要→End Run。其次用小圖接事件／商店／休息／寶箱各一種可到達出口，再驗第一幕 Boss→Reward Continue→generate_next_act、舊圖清除／保留終點與第二幕入口。最後 Boss 必須由真戰鬥完成，RunSummaryOverlay:74 的 combat_ended 判 is_end_of_run 發 run_victory，一般 RewardOverlay 不顯示終局戰利品；之後 End Run→Global.end_run→刪 run save→StatsHandler.win_run→save_profile→再開。若改終局先領獎，是 Reward／RunSummary 轉移責任變更。

存讀邊界已沿 ActionVisitLocation、FileLoader:408–475、Global:282–325 及 ProfileData 核對。start_run 與進點前 autosave；進點先改位置、清 shop，再存，再發 map_location_selected。load_game 還原 PlayerData／RNG／stats 並重送 run_started 與目前位置。能量、格擋、手牌、敵人、action queue、待領 reward 不構成完整快照。QUIT 保留最近 save、不補存、不記勝敗；LOSS／VICTORY 在 End Run 才持久化。起點選擇／獎勵／購買／休息／事件完成／跨幕後尚未進下一點時會有 checkpoint 回退，規格須接受或另設完成標記與恢復路由。

ProfileData 保存勝敗、各角色統計、連勝敗、時間、最高通關難度與歷史；不是通用解鎖／永久能力系統。永久牌組只跨戰鬥。局外新能力需要新增 model、讀取端、結算時機、舊檔預設與去重，不能只放 player_values。NewRunMenu setter 忽略傳入 value 的既有缺口已在 source 重現為靜態控制流程；Global.forfeit_run_from_title 也沒有檢查 load_game 成功便 delete_save／lose_run。難度成長與壞檔放棄不可宣稱可用，需定義範圍或補專項。

可用驗證命令是 `./tools/test-game.ps1 -Suite Smoke`、`-Suite Combat`、`-Suite SaveLoad`。已靜態核對 runner ValidateSet 與固定入口；沒有 GameFlow／FullRun suite。Combat 由 NewRunMenu、起點與真地圖 button signal 走單戰，fixture 把起手牌改成五張原生牌並覆寫 event ID；SaveLoad write/read/rejected 為跨程序，讀後挑鄰接點再直接呼叫 generate_visition_location。它們是基準，不證明原創內容、整幕與最終勝利。

需新增整局專項並由 runner owner 接選單、入口、完成標記、隔離、deadline 與錯誤傳遞，或把明確呼叫接到現有測試入口；只新建 helper 不會執行。專項要驗兩幕圖不變條件、真 Map 到達各節點、Boss 真勝利、profile 勝利／loss/history 只計一次、save 刪除、再開資料清除，以及起點、進戰、完成未移動、跨幕前後、摘要未結算、結算後重啟的跨程序 checkpoint 對照。壞 JSON、無效角色、舊 ID、缺欄位與 mod 不相容依產品政策補拒絕／遷移；拒絕不應替換活 run。不得沿用固定套件名稱假稱新增專項已可執行。

C 結果：導航可執行（pass，僅靜態）。未決為原創核心玩法、角色／牌組、幕數／局長、各資源決策、最終領獎政策、checkpoint 承諾、局外成長與舊檔策略。未驗遊戲行為、畫面／輸入、音訊、平衡及 export。沒有把既有歷史 PASS 記成本輪執行。

## A/B 文件凍結後復查

收到協調者 freeze 後，重新讀 level-design 入口、combat、noncombat、map-act，再讀 noncombat 分析。原先缺失的 `analysis/slay-the-robot/design/noncombat.md` 此時存在且可讀；未依作者摘要推導結論。其 source 連結能帶到下一步，包含 Dialogue schema／Overlay、ShopData／購買 action、RestOverlay／RestActionData、Chest／ActionOpenChest／ActionGrantRewards；本輪選讀的實檔可定位。首次 blocked 保留為文件尚未凍結造成的中斷；以下是後續 recheck。

### A：普通、精英與 Boss

路由是 WORKFLOWS → game-dev → level-design → combat，單敵細節再走 enemy-design，地圖走 map-act，JSON／啟用走 content → bootstrap，核實由 design/encounters 指向 source。已讀 EventData、EventPoolData、ActData、LocationData、EnemyData、EnemyContainer、ActionGenerateAct，以及 generator 的既有事件 IDs。首個內容檔可從獨立 mod 的 `enemies/enemy_original_normal.json` 開始，再建 elite／boss；若選擇沿用既有敵人，則第一個是 `events/event_original_normal.json`。上述 original 名稱是候選工程 ID，未實際建立，也不代表玩法已確認。

第一批共通登記是 `game/external/mods/mycardgame/mod_info.json`，以 game 根相對 folders 配 EnemyData／`_id_to_enemy_data`、EventData／`_id_to_event_data`、EventPoolData／`_id_to_event_pool_data`、ActData／`_id_to_act_data`，然後 `game/external/mod_list.json` 啟用且指定載入優先序，保留 external 與現有項目。properties／patch_data envelope 依 bootstrap；typed enemy_intents 不當普通字典深合併。

以 `event_act_1_easy_combat_1`、`event_act_1_miniboss_1`、`event_act_1_boss_1` 作來源範例；先定敵人角色、intent_initial 到完整循環、生命界限、預告與反制，再建立 `event_original_normal`／`event_original_elite`／`event_original_boss` 的每槽加權敵人字典。EnemyContainer 逐槽抽樣；一個陣列元素是單槽候選，不是整隊組合。召喚 Boss 使用 positional placement，positions 足夠覆蓋初始及召喚槽；只剩 minion 是否結束須另外測。資料合法性先驗 ID、權重非負與正總和、無空 next intent。

接著建普通／精英／Boss pool 與有效 fallback，Act 的 easy/hard、miniboss、boss 欄位分別引用。地圖 LocationData.location_type 必須是 COMBAT／MINIBOSS／BOSS；Combat._on_map_location_selected 正是依此啟動戰鬥，改 enemy_type 不會改節點。池去重洗牌、抽中即移除；固定 location_event_object_id 優先。若指定三種遭遇必定可玩，應在自訂生成 action 建固定可達位置及 event ID，再由 Act.act_action_script_path 接入；僅入池不保證每局出現。沿預設圖則普通在前後層、精英 k=4、Boss 末端；不能只減 floors_per_act 期待商店／休息等自動重排。

Map._on_map_location_button_up 驗 can_travel 與鄰接，ActionVisitLocation 不驗鄰接。實作後接線驗收應由真 Map button signal 進入新事件；測 fixture 直接改 ID 僅適合控制戰鬥，不能證明自然入池。一般獎勵在 combat_started 生成，event_has_combat_rewards 為總開關，沒有 EventData 金錢 budget。非終局 Boss 經 Reward Continue 跨幕；最終 Boss 直接摘要，須與 C 的 max／next IDs 政策一致。

A 的可執行既有命令是 `./tools/test-game.ps1 -Suite Smoke` 與 `-Suite Combat`；池／RNG 或 ID 相容有變再用 `-Suite SaveLoad`。新增內容的 Smoke helper 可沿 bootstrap 在起手 ID 檢查後、example_mod probe 前接入。行為專項需測新敵人的首輪／完整循環、各分支、提前死亡、獎勵、召喚空滿槽、只剩 minion、Boss 跨幕及最終勝利。地圖須直接斷言 ID／邊存在、起點可達終點與無意外死路，再做多 seed 分布；固定牌組／策略記回合及生命損失，有限樣本不代表平衡。runner 沒有 Encounter suite；如新增，須實際修改 ValidateSet／選取／入口／marker，不能把檔名當命令。

存讀先保留目前進點前 checkpoint，PlayerData 保存圖、池、RNG，讀檔重新進當前戰鬥；改 event／enemy／act ID 要定舊檔相容、遷移或拒絕。現有 failed_event_object_ids 從未加入項目，BLACKLIST 也未在補池過濾；難度 override cache 未篩玩家難度。文件有揭露，source 靜態吻合，依賴這些能力時先補機制回歸。未決為實際敵群設計、起始牌組／生命、難度目標、獎勵與必現政策。A recheck 結果 pass（可列具體開工計畫；未實作／未執行）。

### B：選項事件與三種設施

路由是 WORKFLOWS → game-dev → level-design → noncombat → design/noncombat；地圖接 map-act，資料接 content／bootstrap。第一個內容檔可為 `game/external/mods/mycardgame/dialogue/dialogue_original_trade.json`，候選 ID `dialogue_original_trade`，內嵌 state `state_offer`、options `option_pay_health`／`option_leave`，再建 `events/event_original_trade.json`、非戰鬥池，接 Act.act_non_combat_event_pool_object_id。mod_info 用 DialogueData／`_id_to_dialogue_data`；states/options 沒有 Global table。

最短來源 generator.add_test_dialogue 是 dialogue_pick_something：範例扣 10 HP 換 100 money，或付 50 money 換 rare card。實作先寫每項門檻、成本、獎勵、拒絕／死亡與 next ID；state 指 option IDs，initial 指真實存在 state，空 next 是正常結束，未知 next 雖也退出卻不可當合法分支。若必定可遇，生成固定 EVENT 位置，不只丟進概率池。

健康 validator 用 `res://scripts/validators/ValidatorPlayerHealth.gd`／health_amount，金錢用 ValidatorMoney.gd／money_amount，二者皆 >=。效果用 `res://scripts/actions/combatant_actions/ActionAddHealth.gd`／health_amount 與 `res://scripts/actions/combatant_actions/player_actions/ActionAddMoney.gd`／money_amount；HP target_override 參考 BaseAction.PLAYER。DialogueOverlay 建玩家來源／目標與 fake request，ActionHandler.add_actions 預設 enqueue=false、stack pop_back；所以若契約先扣成本再給獎勵，頂層 payload 排 `[獎勵, 成本]`，並驗真正執行時序，不能原樣抄 generator `[扣 HP, 加錢]` 後聲稱先扣血。按鈕 init 才驗門檻，handler 無通用再驗／忙碌鎖／回滾，強制一次性或原子交易要新增原語及失敗測例。

設施接線以自訂生成中的 LocationData 類型為第一個修改點：SHOP／REST_SITE／TREASURE 不必偽造 EventData 欄位。商店由 Combat 顯示 Shop 按鈕→shop_opened→ShopOverlay→ShopData.visit_shop。供貨數量、價格範圍在 ShopData 常數，實際購買是 ActionShopPurchaseItems；若任務只要節點，用現有能力先接位置；若要求自訂供貨或價格，具體改點是 ShopData 或 ActionShopPopulateItems 的供值／interceptor，不能填 Act 的未知 price。ShopOverlay 未建卡牌移除服務。source 的 get_shop_card_price 對已不在庫存的卡回 0，購買 action 沒有全面過期請求 guard，重複交易要專測／修機制。

休息新增 `rest_actions/rest_action_original.json`（RestActionData／`_id_to_rest_action_data`）後，接 PlayerData.player_available_rest_action_object_ids。RestOverlay 消費真實 rest_actions：EXCLUSIVE 排除互斥選項，INCLUSIVE 只限自己一次，INCLUSIVE_REPEATABLE 不排除；可取消選牌 auto_end=false，成功嵌套 payload 發 rest-action-end。generator:469 以 40% heal exclusive、upgrade repeatable 且可取消作範例，不能直接套每營地只升級一次。

寶箱由 Chest._on_button_up→ActionGenerator.generate_chest_open→ActionOpenChest→ActionGrantRewards→RewardOverlay。調收益是在實際 action/interceptor 供 chest_has_money、chest_generates_money、chest_money 等；指定遺物 key 是 artifact_ids。consumable 區塊 TODO 被註解，旗標存在不足以實現掉落。Chest 隱藏只管畫面，LocationData 沒有已開箱欄，重入及存讀的一次性須補測或擴充。

B 先驗新 dialogue ID／state／option／event／pool／act 引用，再真 Map 到達，檢查每選項門檻前／恰達、未選無副作用、實際先後／資源差值、正常返回／死亡、重入。Shop 測足額／不足額／滿消耗槽／下架／重放；Rest 測取消不耗次、互斥、單次／重複；Chest 測開啟／每種領取／放棄／Continue／重開。現有命令仍 Smoke／Combat／SaveLoad，沒有 NonCombat suite；專項需接 runner 後才有新命令，從 combat_flow 的場景／idle／handler 模式重用，不沿用其 event 覆寫作自然可達性證據。

存讀同樣是進點前，Dialogue current state、Rest excluded、Chest 開箱不在完整互動快照。ShopData 雖可匯出，通常 autosave 在開店交易前；load_game 發訪問訊號而不重跑清 shop 的 action，不能誤稱讀檔總會清掉已存 ShopData。完成未移動→QUIT→Continue 的回退與下一點保存後續玩要分開驗。Shop／Reward Continue 可跨幕，Rest 不呼叫 generate_next_act，Dialogue 只回 Map，故 EVENT／REST 做非終局死端需新增出口機制。未決為實際代價收益、是否致死／取消／一次性、設施客製與保存承諾。B recheck 結果 pass（原缺檔已補，靜態路由可執行；未實作／未執行）。

## 本輪證據與交付限制

本輪實際命令只讀文件／程式、定向 rg、git status／rev-parse 並寫此報告；上述遊戲 suite 是已核對存在的將來驗證入口，沒有執行結果。無新遊戲檔、無新增 suite、無任何 runtime PASS。共同文件 lint 由協調者整合跑，不在本檔假稱完成。A/B freeze recheck 與 C 靜態計畫均足以開始後續已授權實作；產品未決條件、既有機制缺口及未驗 UI／平衡不被轉成「框架已完成」。
