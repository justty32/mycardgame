# UI 專項驗證與 fixture 接線

[UI 入口](../ui.md)｜[互動狀態](interaction-states.md)｜[tooltip](tooltip-refresh.md)｜[選牌](card-pick-modal.md)｜[元件版面](components-layout.md)｜[驗收分流](../validation.md)

**何時用**：要證明 UI 改動的資料、handler、顯示狀態與幾何契約。

**何時不用**：文件冷讀只跑文件檢查；視覺與真實輸入的驗收不在本篇範圍，操作邊界見 [user.md](../../common/user.md#桌面與程序邊界)。

## Done when

任務結果檔有 fixture 前提、實際呼叫入口、逐項斷言、執行命令與日誌；適用命令回傳預期結果且新增斷言確實執行。沒有背景專項、真實輸入或視覺證據的項目明列未驗。

## 流程

### 既有證據能到哪

[framework_smoke.gd](../../../../tests/framework_smoke.gd) 載入 main scene、實例化 Root、等待兩個 frame，驗 TitleScreen/MainMenu 與 NewRunButton ready。它不是任意畫面／theme／字型／viewport 的自動驗收。

[combat_flow.gd](../../../../tests/combat_flow.gd) 配 [combat_fixture.gd](../../../../tests/combat_fixture.gd) 建立有效 run、地圖與戰鬥，實際發卡牌／敵人／按鈕 signals；含出牌、能量不足拒絕、敵人回合、勝敗、金錢獎勵及 draft 選牌後持久牌組 +1／ID 相符。既有 `_claim_rewards()` 不驗 Skip、取消、tooltip、焦點、重複確認或多尺寸；`_snapshot()` 記資料，不是截圖。

[ResourceLifecycle](../../../../tests/resource_lifecycle.gd) 驗既有 action／interceptor 等清理；新 modal、timer、全域訂閱與 owner 退出仍需對應斷言。不能由 All 綠燈推論新元件已被覆蓋。

### 把新增 helper 真正接上

[runner](../../../../tools/test_game.py) 只接受 All／Dictionary／Combat（含 CombatVictory／CombatDefeat）／SaveLoad／Smoke／ResourceLifecycle，沒有 UI suite。它複製 tests 頂層 `.gd`，**不會自動執行新 helper**；`--source-game` 只換 game 來源，tests 仍取 runner 所屬專案。候選副本方式見 [bootstrap](../content/bootstrap.md)。本篇的 helper 名稱是後續實作建議，目前不存在。

靜態布局可建 tests/ui_layout_probe.gd（extends RefCounted），在 Smoke `_run()` 的 Root.add_child、兩次 process_frame 後、example mod probe 前，以 `load(get_script().resource_path.get_base_dir().path_join("ui_layout_probe.gd")).new()` 載入；呼叫其 `check_scene(game_root)`，把回傳的每筆 label／bool 交既有 `_check()`。若 helper 自己等待 layout，將方法設為 async 並由 caller await。需先建 helper 才插呼叫，不留無法載入的範例路徑。

HUD／卡牌狀態 helper 可接在 Combat `_wait(_player_ready, ...)` 成功之後，既有 `_scenario()` 後續勝利出牌／`_defeat_flow()` 分支之前；只讀預覽或暫時選取／取消的 probe 須還原，不能改 HP／牌組破壞固定傷害斷言。獎勵 Skip 應另設情境，或在 `_claim_rewards()` 第一個 draft 開啟後驗 skip，再透過正式 reward action 提供第二次 draft 驗 claim；明列 fixture 差異，不直接 emit 勝利或竄改 HP 假造流程。需要新 suite 時連 runner 的 SUITE_CHOICES（及 ps1 包裝的 ValidateSet）、選擇分支、script mapping、PASS marker／結果 manifest 一起接，交測試入口 owner 整合。

helper 在 autoload ready 後才 runtime load，避免開頭 preload 提早解析遊戲全域 class。以既有 `_wait()` 型態等待 action idle／畫面狀態，有明確 timeout；不要固定睡一秒猜完成，也不要忽略 fail 繼續列 PASS。queue_free、Card 延後刷新與字級調整各自等待，最終移除 Root 並確認待選 action 沒有懸掛。

### A：HUD／目標／tooltip 的最小專項

以既有勝利 fixture 作有效 combat 起點：比對 EnergyCount、三個牌堆 Count、HealthLabel／MoneyLabel 與 owner 資料；透過正常 action 改值並等待刷新後再比對。回合按鈕還需驗 disabled／排隊結束，不能直接把 label 寫成預期值。

取得手牌中 requires_target 的 Card，發 card_selected 後核對 current_selected_card／SelectTargetLabel；發 background button_up 後核對清選、能量／敵人 HP／牌堆未變。另一分支選敵人後沿既有流程核對恰一次 request／費用／效果。禁止分支包含 hand_disabled、費用不足、同牌已在 queue；右鍵有自訂 action 的卡另驗，不能當通用 cancel。

tooltip fixture 準備至少一個有效 KeywordData；呼叫 hover／timeout handler 只驗 timer／展示接線，核對文字、KeywordTooltip 個數、退出後隱藏及 queue_free 完成。多次展開與同 frame 換目標前後，記 card_keyword_object_ids 等卡資料、能量、牌堆、具名 RNG state／action queue，辨識預覽副作用。KeywordContainer 會追加推導 keyword 的現況須先列為既有差異，若修正它才要求資料不變；不把新要求偽裝成舊測試。

### B：modal／獎勵的最小專項

用真實 ActionPickCards 與 CardData 候選，多於 min 才能進人工選取；宣告 pick type、min／max、quick pick、can_back_out。Hand、deck VIEW／SELECT、draft 是不同 consumer，各自驗零候選、選取／取消選取、足額、不合法牌、Confirm／Back／Skip 與隱藏；零候選可能由 Action 自動結束，別硬等 modal 出現。

正常取消核對 picked_cards 空；若要求子效果未執行，ActionPickCards fixture 須設 min_card_amount=1、min_cards_are_required_for_action=true（can_back_out 僅控制返回可見）。draft Skip 後原 CardRewardButton 保留，另驗可重開；draft claim 核對 deck +1 及 ID；重複點擊／確認不得重複結果。等待中以受測場景自己的退出流程清 actions，核對 async_finished／async_cancelled、UI 參照與待選信號釋放，重進後只完成一次。這些是待補斷言，不是現有 suite 保證。

鍵盤／手把實作後，可背景驗 action 定義、focus neighbor 路徑、可聚焦元件、可取消／不可取消 handler 和一個事件不穿透兩層。背景專項不呼叫真實 grab_focus、不操控視窗；背景 property／handler 不證明實際導覽、按鍵重複、控制器型號或輸入延遲。

休息／非 Draft 選牌的具體 caller 與成功、Back、退出、重入專項分別見 [rest-services](screens/rest-services.md) 與 [card-selection](screens/card-selection.md)。換點清 dictionary 後再送舊 rest_action_ended，應拒絕舊 generation 且不重開；目前 guard 未實作，不可忽略失敗。

### C：版面、字型與證據層級

版面 fixture、虛擬 viewport、動畫基準與證據分層見 [headless 幾何驗證](headless-geometry.md)。保留可用區、裁切、落腳與重開 run 斷言；不能用 headless 預設視窗值冒充目標尺寸。

## 命令與交接

從專案根跑 `python3 tools/test_game.py --suite Smoke`（共享場景／版面）、`--suite Combat`（戰鬥／獎勵 handler），清理變更加 `--suite ResourceLifecycle`。讀 artifacts/verification 當次 results.json、engine／console log 與專項 assertion；通過須符合 [testing](../../testing.md)，不能只看 exit 0。

文件 lint 見 [testing](../../testing.md)。交接列出 source／test hash、fixture、候選根、suite／helper 呼叫位置、測過的狀態與尺寸、未驗視覺／輸入，讓下一位能重現而不依對話記憶。
