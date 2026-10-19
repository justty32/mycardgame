# 獨立冷接手：卡牌、機制、呈現與 fresh clone 六案

2026-10-19。受測者從 `wf/WORKFLOWS.md` 開始，未讀其他冷接手報告或 onboarding 結果表，未使用其他 repository、對話或 agent 筆記。本文是首次讀取結果，不是遊戲實作／驗收報告。只寫此報告；未改 game、tests、tools、wf、analysis，未產素材，未啟動 Godot、GUI、聲音、截圖，未操作既有程序，未 commit／push。

## 初讀與核對方法

開場 `rg -c '^- \[' wf/SESSION-LOG.md wf/WAIT_USER.md` 找到 SESSION-LOG 一筆，WAIT_USER 無匹配，已讀 open 狀態。派發器把新接手導向 agent-session、五案導向 game-dev。已通讀 agent-session 指定的根入口、STRUCTURE、INDEX、PROJECT、模板、common 入口、user、conventions、code-map、data-files、learning，再讀 dev-env、feature-dev、testing、validation。資料欄位表透過 tabledb 的 slice 讀取，未整份直接讀 JSON 表。

`git -C game rev-parse HEAD` 回 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`；`git -C game status --short` 顯示 13 個既有修改檔，與 upstream.json 所記本地修復領域相符，未改動／清理它們。沒有把 checkout HEAD 當作含修復的全部內容身份。

追讀只沿工作流、分析及其來源連結。`rg` 限定在已導向的 Global、產生器、CardData、PlayerData、Random、Scripts、Root、ActionHandler、BaseCombatant、Card 與 runner 等檔案查 ID／方法；未用全 repository 搜尋反向補導航。以下擬議 ID 和數值只是演練用可替換參數，不是已決定的核心玩法。

## 案一：新增可升級攻擊卡，進起手與獎勵

初讀路由是 WORKFLOWS → game-dev → card-design → content → content/bootstrap；schema、取得行為由 design/cards.md 接 CardData、CardPackData、PlayerData、GlobalTestDataGenerator，最小 JSON 由 bootstrap 接 beginner_guide_zh。這條路可開始實作，未出現必須靠全庫搜尋才能找到責任檔的中斷。

第一個新檔可為 `game/external/mods/mycardgame/cards/card_review_strike.json`，穩定 ID `card_review_strike`。示意契約為紅色 COMMON ATTACK、1 費、指定單一敵人、基礎 6 傷害、首升 +3、上限 1；數字須由正式 brief 取代。採 `properties`／`patch_data` 外殼，`card_values={damage:6, number_of_attacks:1}`、`card_upgrade_value_improvements={damage:3}`、`card_appears_in_card_packs=true`，`card_play_actions` 指向 `res://scripts/actions/combatant_actions/ActionAttackGenerator.gd`，payload 不重複寫 damage。由 source 可確認升級先首升覆寫、再 improvements；預設上限 1，第二次升級應不再變值。升級驗證必須用 `Global.get_card_data_from_prototype()` 所得獨立牌，不能改只讀模板。

接著建立／增量修改 `external/mods/mycardgame/mod_info.json`，cards 映射 `CardData/_id_to_card_data`、characters 映射 `CharacterData/_id_to_character_data`，key 以 game 根起算。角色 patch 檔 `characters/character_red.json` 用 `object_id=character_red`，對 `character_starting_card_object_ids` 指定 append，只加入新 ID 一次。最後在 `game/external/mod_list.json` 保留既有項，啟用此 mod 並指定不碰撞 priority。既有 `character_red` 已引用 `card_pack_red`，該 pack 篩 `color_red`；本例可用既有 pack，毋須新增 pack。起手原有三張基本攻擊、三張基本格擋和其他牌，不能誤以為正式角色只有六張牌。

驗證分成載入、出牌、取得。依 bootstrap 新增 `tests/review_card_probe.gd`，於 framework_smoke._run 的起手 ID 解析迴圈後、Array／Dictionary／example_mod probes 前載入，結果逐項交 `_check()`。查 `Global.get_card_data()`、起手 count、保留原起手、`Global.get_cached_card_filter("card_pack_red").filtered_card_unique_object_ids`；新 run 再查永久牌組、`player_reward_card_filter_cache` 與 `player_reward_card_rarity_cache`。費用／升級／超上限／拒絕目標／不足能量／格擋／出牌去向用新專項，不把 Smoke 的建立 action 視為傷害證據。

Combat fixture 會覆寫起手，且 `_play()` 固定扣 1；不能原封不動跑 Combat 宣稱新卡已驗。具體接法是在 `combat_flow.gd` 加一個明確呼叫的新卡 helper，由同一 `_check`、`_wait`、`_idle` 與 `_finish` 管理；新 helper 自有 fixture／期望成本，不套既有 65 HP、20 傷害的固定勝利序列。獎勵沿 `_claim_rewards()` 的真實 CardRewardButton → draft → card_selected → deck 增加路徑，選到新卡才算新卡取得；測試可固定專項 draft 候選，但正常池收錄另行驗證，不能以強制候選取代池證據。Smoke、Combat 是現有命令；Cards suite 不存在。

交接附 card/mod/character/pack ID、基礎與升級期望、JSON 與測試 hash、每項 PASS 標記與日誌。永久升級如需存檔相容，把新卡放入 SaveLoad 的實際快照再驗；原生 SaveLoad 通過不能代替它。實跑、平衡、視覺和新卡存讀本輪全部未驗。

## 案二：比較兩卡版本，決定是否調費

初讀路由是 game-dev → card-evaluation → card-evaluation-fields.json、design/cards → combat_flow/combat_fixture。流程明說沒有平衡 runner／策略／統計工具，因此可準備實驗，但不能交出現成「跑平衡」命令；這是真正未實作能力，文件沒有假裝它存在。

第一個應寫的是本次評量規格／資料檔，先固定 A/B 卡 ID 或相同 ID 的兩份候選來源、只改費用的干預、相同升級／牌組／遺物／HP／難度、種子集合、合法決策策略與停止門檻。若沿案一，A 為 1 費、B 為 2 費只是待比較候選，先完成兩版功能測試，不先承諾調費。實際遊戲數值入口仍為候選 mod card JSON 的 `card_energy_cost`；兩版在不同候選根運行，保留內容 hash，避免載入優先序把對照覆蓋掉。

可定位遭遇由文件直接給出：GlobalTestDataGenerator 的 `event_act_1_easy_combat_2`／`enemy_3`、`..._3`／enemy_1+enemy_2、`..._4`／enemy_4。前者帶死亡效果，中者有首傷免疫，不能當乾淨木樁。先用明確 fixture 驗費用邊界與效果，再選這些真實情境做配對。修改順序為規格 → 新增評量 helper → 將 helper 明確接入 Combat 入口 → 先少量驗證合法策略與 timeout → 預先留好的 seed 做正式比較。需要擴充 runner 的 suite／scenario 時，必須實改 ValidateSet、映射、標記、隔離與退出契約，完成後才可寫新命令。

目前可用命令只有 `./tools/test-game.ps1 -Suite Smoke`、`-Suite Combat`，加上候選根 runner 的既有參數；它們原樣只是基準，不會產生 A/B 勝率。新量測至少留下每次決策、實付能量、抽到／可用／使用、有效傷害／過量、承傷、回合、失敗／逾時、RNG trace。沿既有 `_play()` 用真實 card_selected 和敵人選擇 handler，將固定扣 1 改成專項明確期望成本；不能用直接改 HP 製造結果。逐 seed 配對，不把同 seed 重跑當獨立樣本；區間方法、樣本量和停止規則須先定，現有工具未自動完成。

本輪結論只能是「尚無樣本，不能決定調費」，不是 A/B 等效。正式交接應帶候選 hash、scenario／seed／策略版本、樣本分母、失敗紀錄、統計方法與下一個保留／調整／補測決策。人工體驗與樂趣仍未驗；這個邊界不構成導航失敗。

## 案三：新增需要 Action 與 Interceptor 的效果

首次判定：`blocked`，範圍限定為「新 Action 帶攔截／拒絕行為時，從入口完整走到 Card 預覽的實作計畫」。能找到執行與註冊 API 不足以消除下述缺口；本初讀紀錄保留，不因後續修補改寫成首次成功。其他非預覽接線仍可準備。首次提交時修補後獨立復查為 pending，追加結果見下節。

初讀路由為 game-dev → mechanics → ActionGenerator、ActionHandler、BaseAction、ActionInterceptorProcessor、ActionInterceptorData、StatusEffectData、BaseCombatant；新 mod 資料外殼回 content/bootstrap。核心機制可開始，惟下述預覽接線有一個值得補入入口的缺口。

正式規則未提供，不能替使用者決定效果。工程上第一個應改檔可以明確指定為 `game/external/mods/mycardgame/scripts/actions/ActionReviewEffect.gd`：繼承 BaseAction，覆寫 perform_action，先 `_intercept_action()`，對接受的 processor 用 `get_shadowed_action_values()` 讀值，才套用已定義效果。payload 用完整 `res://external/mods/mycardgame/scripts/actions/ActionReviewEffect.gd` key；ActionGenerator.create_actions 只 init，交 ActionHandler.add_actions 才執行。無新資料型別時不需改 Global schema，也不強制加 Scripts 常數。

下一個檔為 `scripts/interceptors/InterceptorReviewEffect.gd`，繼承 BaseActionInterceptor，覆寫 `process_action_interception(processor, preview_mode)`，透過 `set_shadowed_action_values` 寫入，不直接改原 action values。再建 `action_interceptors/interceptor_review_effect.json`，填 script path、精確 intercepted action path、parent/target 端與 priority；mod_info 映射 `ActionInterceptorData/_id_to_action_interceptor_data`。若效果由狀態持有，建 `status_effects/status_effect_review.json`，以 `status_effect_interceptor_ids` 引用，映射 `StatusEffectData/_id_to_status_data`。BaseCombatant 首次建立狀態會 register，最後移除會 unregister；只讓一個 owner 持有同 ID，不能只把資料入表就算生效。source 已核對排序為 priority 高者先，同值 ID 反向。

新 action 陣列預設後項先執行；若用 enqueue=true 才沿 queue 正序，子 action／sentinel 另驗。若需 await，改用 BaseAsyncAction 契約 begin/finish/cancel，不能在普通 perform_action 裡 await 後假設 handler 會等。驗收 helper 接 Smoke 做載入與建立；行為 helper 明確接 Combat，覆蓋無攔截、來源端、目標端、priority、CONTINUE/STOPPED/REJECTED、null parent/card/target、重複註冊／移除與預覽不改狀態。持有 processor 或 async 時加 `./tools/test-game.ps1 -Suite ResourceLifecycle` 的新專項，而不是只重跑原有清理案例。

精確操作橋接缺口：mechanics 的「攔截與 validators」要求預覽無副作用，卻未寫出 Card 預覽會直接取 `_intercept_action(..., true)[0]`。沿 ui 所導向的 `game/scripts/ui/card/Card.gd:174` 查到 get_card_description，205 行直接索引；BaseActionInterceptor 的註解明確說 preview 不應 REJECTED。因此正式 interceptor 若真實拒絕效果，preview 分支仍須避免回空陣列，或另設計並測試 Card 的空結果契約。只照 mechanics 的回傳碼說明會漏掉這個 UI 邊界。

同一來源另顯示預設只預覽 ACTION_ATTACK/ACTION_BLOCK；新 action 的可變值需要 `CardData.card_description_preview_overrides` 的 `[值 key, action 路徑]` 接線，否則第二輪只以未攔截 card_values 替字。card-design 泛稱核對預覽映射，但 mechanics 沒有把這個具體欄位與禁止 REJECTED 一起帶入新 Action 步驟。可在 mechanics → 預覽段補一個最短連結／例子；本輪只報缺口，未改文件或產品。

交接保留 action／interceptor／status IDs、owner、priority、values、preview 行為、同步／非同步終止條件、合法與拒絕證據。以上為靜態契約；沒有執行新機制，也未證明實際預覽正確。

## 案四：為新卡導入圖片、音效並接 UI

初讀路由為 game-dev → art-assets 的「一張新卡跨領域接線」→ audio／ui → presentation/audio 分析 → FileLoader、Card、ActionPlaySound。能找到第一個資料欄位及實際消費端，且素材來源、聽感和無聲測試分層清楚。

第一批檔案可定為 `game/external/mods/mycardgame/sprites/cards/card_review_strike.png` 與 `audio/sfx_card_review_strike.wav`，前提是正式 brief／合法來源已選定；本輪不製作。圖輸出以既有 96×96 框評估，母稿另存，不能烘入規則文字。先檢查解碼／尺寸／alpha、音檔編碼／聲道／採樣率／時長，再改 card JSON 的 `card_texture_path` 為完整 game 相對路徑。圖片走 FileLoader.load_texture，不是相對 JSON 目錄，也不是單靠 .import。Card.update_card_display 延至下一 process frame 後寫入 CardTexture，故測試須等刷新。

音效若契約是「每次成功出牌一次」，在 `card_play_actions` 加完整 ActionPlaySound 路徑及 `audio_path=external/mods/mycardgame/audio/sfx_card_review_strike.wav`，`audio_path_is_absolute=false`；要先播聲再攻擊，預設 stack 下聲音放陣列後項。若是「每擊一次」，ActionAttackGenerator source 也有 audio_path 產生每擊音效的路徑，不能兩條同時接造成重播。真正命中與成功出牌是不同條件，需要另定，不能把 action 位置直接當命中事件。

先在 Smoke helper 驗 loader 結果不等於 FileLoader.MISSING_TEXTURE／MISSING_AUDIO、解碼尺寸／stream 規格符合，再實例化 Card、init、等待刷新，查 texture、卡名、費用和描述。loader 非 null 或 resource_path 相同不夠：source 的 fallback 也會 take_over_path。WAV loop 強制關閉，OGG/MP3 loop 只由第一次路徑 cache 決定；純新卡短音效不需擴充混音系統。按 content/bootstrap 接 helper 才會跑；不存在 Audio suite。

精確未實作能力：`tools/test-game.ps1:233` 只放 --headless，未明列 Dummy 或注入替身；現有 tests 沒有可直接拿來計數新卡播放呼叫的 helper。audio 工作流已誠實說明這點。故在目前規則下可完成檔頭與引用計畫，播放路徑不得直接使用現有 runner 試播。正式實作需先由 runner owner 建立並證明無實體輸出的 Dummy／替身方法，再從真實成功出牌路徑驗播放一次、預覽與拒絕零次；這是必要新測試工程，不是假想現成命令。

交接將同一 card ID 串到圖／音路徑、來源與使用條件、顯示框、播放事件、action 陣列順序、helper 呼叫點和素材 hash。背景通過仍不能證明縮小辨識、裁切、安全區、聲音接縫、聽覺疲勞或 export；本輪連 loader 都未執行。

## 案五：主選單／結算原創風格、繁中與多尺寸

初讀路由為 game-dev → ui → ui/menus-localization → presentation → Root、MainMenu、BaseMenu、RunSummaryOverlay、theme、combat_flow。可找到實際節點、文案和測試耦合，不須猜獨立 MainMenu.tscn 是否存在。

第一個遊戲修改檔是 `game/scenes/Root.tscn`：主選單在 `TitleScreen/MainMenu`，結算在 `RunScreen/RunSummaryOverlay`。先將正式 brief 固定的風格、文字、字級下限、狀態和目標 viewport 寫成規格，再調根容器、overlay、message、stats 和按鈕的 anchors／container／minimum size。1200×700 是基準，候選小尺寸與不同長寬比不是自動承諾；只開 project.godot resizable 不能解除既有固定 offsets。

然後改 `game/themes/title_screen_theme.tres` 的本次共用樣式或新增局部 Theme，保留導航、腳本 NodePath、UniqueName 與訊號契約。加入合法繁中字型並記版本／授權，確認主選單 Theme 與結算局部 font override 分別生效。文案改 Root 的固定 text、RunSummaryOverlay 的 VICTORY_MESSAGE／SUMMARY_TEMPLATE，敗北文案沿目前 EventData.event_death_message_bbcode。保留 SUMMARY_TEMPLATE 對應的統計 key；不要翻譯資料 key。若本次只有繁中，不擅自增加完整多語系統。

狀態應涵蓋無 save 時 NewRun、存在 save 時 Continue／Forfeit、勝利、敗北、返回。MainMenu source 透過 FileLoader.has_save_file 決定可見性；BaseMenu 用 navigation_button_to_menu 綁 button_up。結算按鈕雖寫 Back To Main Menu，既有敗北測試實際返回 NewRunMenu；風格任務先保留這個行為並改成準確繁中文案，若產品想換目的地再明定為行為修改。`RunSummaryOverlay.generate_run_summary_text()` 空 stats 會 breakpoint，專項 fixture 不能只空 emit run_victory。

Smoke 中接入場景 helper 驗兩畫面實例化、字型取得、字級下限與已知長文字，採每個目標 viewport 等 layout／延後更新後檢查 rect 在可用範圍。Combat 保留真實敗北／返回回歸，將 `contains("Damage Taken")` 替換成繁中文字串加統計數值語意保護，不能刪掉。通關勝利需新 helper 建有效 run statistics 和 EventData，再觸發 run_victory／結算 button handler；現有 Combat victory 只到一般戰鬥獎勵，不能冒充終局勝利。檔案字元集合與字型 cmap 可離線核對，實際 glyph／DPI／滑鼠命中仍需後續授權。

現有命令為 `./tools/test-game.ps1 -Suite Smoke` 和 `-Suite Combat`；沒有 UI suite，僅新增 tests/*.gd 不會執行。操作橋接已明寫 bootstrap helper 的相鄰路徑 load、既有 `_check` 失敗累計及完成標記，足以安排新 assertions。報告需附 scene/script/theme/font 路徑、狀態、尺寸、文字來源、背景日誌與尚未完成視覺／輸入項。本輪未實作原創風格、未選字型、未量測多尺寸。

## 案六：fresh clone 準備第一個 mod

此案是獨立路由判讀，不沿用其他 agent 的 recipe 或執行結果。WORKFLOWS 的「fresh clone 後要做什麼」直接指向 dev-env；該頁說明公開 snapshot 與本機內層 checkout 差異，再導向 game-dev/content/bootstrap。若從「第一個 mod」意圖出發，則 WORKFLOWS → game-dev → content → bootstrap，兩條路能會合，不需靠前五案才能猜環境入口。

第一步是唯讀環境／版本查核，而不是再 clone 上游或套補丁。本輪按 dev-env 實查 PowerShell 為 7.6.5、Python 3.13.0，git/python/pwsh 可解析、Git Bash 路徑存在、game/project.godot 存在。外層 root 是 {PROJECT_ROOT}，本機 game 有獨立 .git，root 為 {PROJECT_ROOT}/game；這只能證明本機環境，不代表已測 fresh clone。來源鎖明列公開 game 已含修復，fresh clone 不應重套 local_patches；沒有內層 .git 時須將 git -C game 的 HEAD 解讀成外層專案身份，上游版本另讀 tools/upstream.json。

真正 fresh clone 需要 PowerShell 7、Python/Git Bash 與 Godot 4.6。引擎取得 URL 和 SHA-512 已由 dev-env 導向 upstream.json；若缺檔先按有效安裝授權處理，下載後比對 SHA-512，再使用 .tools 路徑或 -GodotPath。不能用檔名推定版本，也不能因 Git 身份尚未設定就阻擋背景遊戲檢查。此演練不下載、不安裝、不啟動引擎；沒有把「命令存在」寫成新機可執行證據。

第一個內容檔案集合由 bootstrap 直接給出：game/external/mods/mycardgame/mod_info.json、cards/card_heavy_strike.json、characters/character_red.json，再啟用 external/mod_list.json。教學卡 ID 為 card_heavy_strike、費用 2、傷害 15、起手 append、暫不進 card pack；它是獨立的 bootstrap 規格，不能與案一可獲得卡的 appears=true 期望混用。JSON 完整例子在 beginner_guide_zh，mod_folder_to_load_data 路徑以 game 根為基準，無須照搬 example_mod 的 script takeover。

若正式實作直接改授權 game/tests，runner 自行隔離；若只是試教學，bootstrap 有完整 PowerShell candidateRoot GUID、robocopy game/tools/tests 的配方，排除 .git/.godot/.import/.saves/.screenshots、external/saves、profile.json、user_settings.json，並檢查 robocopy >=8 為失敗。本輪未建立或執行候選，只核讀配方與 runner 的 Copy-IsolatedGame 一致的排除原則；候選不帶引擎，enginePath 指向已確認的外部引擎檔。

fixture 橋接不是口頭「寫測試」：bootstrap 已提供 tests/mod_bootstrap_probe.gd 的八個結果鍵，檢查註冊、既有起手保留、追加一次、2費15傷、starting-only、AttackGenerator 路徑；在 framework_smoke._run 的起手解析迴圈後、example probe 前用相鄰腳本路徑 load，再交 `_check()`。runner 確實複製 tests 頂層 .gd，但沒有自動發現並執行 helper。不能只建立 probe 檔就說被測；也不可再次調 FileLoader 重載導致 append 重複。

候選執行的真實形式為 `& (Join-Path $candidateRoot 'tools/test-game.ps1') -Suite Smoke -GodotPath $enginePath`，同一 session 先暫存 APPDATA，try 內改為 candidateRoot/user-data，finally 還原。正式根才用 `./tools/test-game.ps1 -Suite Smoke`。`-SourceGame` 只換來源 game，不會換到旁邊 tests；因此要測修改過的 helper，tools/tests 必須在同個候選根。這一點由 runner 的 `$projectRoot = Split-Path -Parent $PSScriptRoot` 和 tests 複製來源靜態確認。

後續驗收要讀候選 artifacts/verification 的 results.json、smoke.log／console log，同時有 completed=true、PASS verdict、SMOKE PASS、八項 PASS: MOD，並符合 exit/錯誤／資源退出規則。只出現舊 SMOKE PASS 不夠。另記 mod 三檔、mod_list、修改 tests 的 SHA-256 和候選路徑；不能把既有 source_hashes 當成新內容完整指紋。

此路由能準備第一個 mod 與載入 fixture，沒有新的導航中斷。它未覆蓋實際重擊出牌，因 Combat 會覆寫起手且固定 1 費斷言；出牌／獎勵／存讀須按案一另接專項。交接狀態為「環境與載入測試工程可開始，未建立 fresh clone、未寫 mod、未跑 Godot」，不得以本機工具存在或文件八個結果鍵視為新 clone 已通過。

## 案三修補後復查：blocked → pass（限靜態開工計畫）

2026-10-19，修補 owner 通知 freeze 後，由本受測者重新閱讀 mechanics 完整入口、沿新連結讀 design/cards 的「卡面攔截預覽的消費端契約」，再比對 Card.gd:174–226、CardData.gd:94–99 及 BaseActionInterceptor。受測者未參與共享文件修補；此為原獨立讀者對修補的復查，不冒稱另一個全新無記憶 agent 的第一次冷讀。前述首次 blocked 原文保留。

目前入口已明寫 preview 不回 REJECTED，並直接解釋 Card 取 `[0]` 的原因；新 action 只有需要顯示自訂攔截值時才設 overrides，非空會取代標準 damage/block。這也修正本報告初讀中「新 action 的可變值需要 overrides」過寬的措辭：未攔截的 card_values 只替字即可，不是一律必填。分析進一步交代假 action payload 為空、player/selected_target 可為 null、只 init/攔截而不 perform_action，所以現在能從 mechanics 直接列出新 action 必須支援的預覽輸入，不須自行從 UI 來源推導漏掉的安全契約。

再核對來源可確認 CardData 的第三欄自訂映射註解未被 Card 消費：Card 只讀 preview_data[0]／[1]，建 `{path:{}}`，未注入 custom_key_names。修補已把此列為機制缺口，沒有把 JSON 第三欄寫成可用。正式計畫因此先採同名 custom_value／card_values／描述占位符與 shadow key 的最短契約；若正式需求必須跨 key 映射，另開產品修復與回歸，不能用文件宣稱已支援。

可執行的新 assertions 已能從該入口直接取得：未選／指定目標、基礎／升級／加成／減益、實戰拒絕條件下反覆預覽；檢查非空 processor、必要 key、無殘留占位符／錯誤 0、預期顯示數值，以及 RNG／充能／牌堆不變，最後比對一次真實執行。實際拒絕與預覽保留 processor 的回傳碼可不同，但顯示期望須明訂。這些加回原案 Smoke/Combat helper 及適用 ResourceLifecycle 的接入點，即有可開始編碼的完整準備鏈。

復查結論為 pass，僅表示這次文件缺口已補到可執行計畫；新 action、interceptor、第三欄映射及上述 assertions 都沒有實作／執行。核對檔案 SHA-256：mechanics.md 為 `6D9357DD72546C9B99B7BAEF4181C8BB814C4BC685B2C6E7418CC391023120E3`；design/cards.md 為 `28B3B50141A30117C1A1DABFA31A56421B124DA1291646014B9FB2339782CB67`。來源仍是先前的 4dac5abe 加本地修復。

## 命令真實性與交付判定

上述引擎命令均只是未來實作後、取得引擎執行授權才執行的計畫；本輪任務明確禁止 Godot，因此沒有遊戲 PASS。runner 實際 ValidateSet 為 All、Dictionary、Combat、SaveLoad、Smoke、ResourceLifecycle，會複製頂層 tests/*.gd，入口與 marker 固定。`-SourceGame` 不會換 tests；完整候選應同時複製 tools/tests 再呼叫候選 runner。新內容／素材／測試 hash 必須另記，不能只靠 runner 的 13 檔 source_hashes。

實際已做的是入口閱讀、tabledb 欄位查詢、指定檔案符號查核、Git 身份／狀態唯讀檢查與本報告落檔。文件整合後的正式 lint 命令沿 testing：

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -c 'function python3() { python "$@"; }; export -f python3; python3 --version && bash wf/tools/wf-lint.sh --strict .'
```

本報告未修改共享文件，由主 agent 整合後執行整體 lint。六案均能提出第一個可修改檔、資料／API 與測試接線；案二的平衡採樣工具、案四的無聲播放專項屬已明列的未實作能力，不能宣稱現成完成。案三首次為 blocked，已保留發現與來源；修補 owner 完成文件後，由本受測者重新沿入口／source 比對，追加復查為 pass，沒有覆寫初讀失敗。所有流程可導航結論都限於靜態準備，不代表新遊戲功能或產品體驗已驗收。
