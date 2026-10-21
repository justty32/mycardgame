# UI 專項驗證與 fixture 接線

[UI 入口](../ui.md)｜[互動狀態](interaction-states.md)｜[tooltip](tooltip-refresh.md)｜[元件版面](components-layout.md)｜[headless 幾何](headless-geometry.md)｜[驗收分流](../validation.md)

本篇是呈現類（UI、動態、聲音、圖像接線）**證據判讀**與**helper 接線**的單一來源；場景篇、美術／音訊子篇只連過來。

**何時用**：要證明 UI 或呈現改動的資料、handler、顯示狀態與幾何契約，或要判斷某份背景結果能證明到哪一層。

**何時不用**：文件冷讀只跑文件檢查；視覺與真實輸入的驗收不在本篇範圍，操作邊界見 [user.md](../../common/user.md#桌面與程序邊界)。

## Done when

任務結果檔有 fixture 前提、實際呼叫入口、逐項斷言、執行命令與日誌；適用命令回傳預期結果且新增斷言確實執行。沒有背景專項、真實輸入或視覺證據的項目明列未驗。

## 流程

### 證據層級與判讀

素材已生成、引用已載入、資料結果已驗、視覺可讀、真實輸入可操作、聲音／動畫同步是**不同證據**，各自記錄。背景（headless）斷言只證明事件、資料、屬性、handler、回呼次數、幾何與清理；不證明命中、遮擋、字形、對比、節奏、演出同步、聽感、焦點導航或手把。需要 GUI、截圖、真實焦點或實際播放的項目標記未執行並明列，不建立 screenshot PASS，也不借用其他任務的成功紀錄。發 signal 不證明滑鼠命中，背景 property 不證明實際導覽、按鍵重複或輸入延遲。

背景專項不呼叫真實 `grab_focus`、不操控視窗。啟動引擎前先以測試 adapter 截斷會動到真實焦點的分支（例如 [Map 自動焦點](screens/map.md#演出焦點與離場)）與聲音播放出口（無聲門檻見 [mixing](../audio/mixing.md)）；headless 不等於無聲／無焦點。

**純呈現 fixture**（音效、動畫、tooltip、預覽）比較前後的能量、牌堆、keyword IDs 等卡資料、具名 RNG state 與 action queue；既有 mutation 差異（例如 KeywordContainer 會追加推導 keyword）先列為既有差異，任務修正它時才要求不變，不把新要求偽裝成舊測試。動到預覽／等待者加生命週期專項。

每個情境驗「成功恰一次、拒絕／預覽零次、取消與強制退出可區分、重開不接舊回呼」；等待中離場要核對 action 完成或取消、UI 參照與自建 Tween／timer／音訊釋放。只看 overlay hidden 或 exit 0 不算通過。

### 既有證據能到哪

[framework_smoke.gd](../../../../tests/framework_smoke.gd) 載入 main scene、實例化 Root、等待兩個 frame，驗 TitleScreen/MainMenu 與 NewRunButton ready。它不是任意畫面／theme／字型／viewport 的自動驗收。

[combat_flow.gd](../../../../tests/combat_flow.gd) 配 [combat_fixture.gd](../../../../tests/combat_fixture.gd) 建立有效 run、地圖與戰鬥，實際發卡牌／敵人／按鈕 signals；含出牌、能量不足拒絕、敵人回合、勝敗、金錢獎勵及 draft 選牌後持久牌組 +1／ID 相符。既有 `_claim_rewards()` 不驗 Skip、取消、tooltip、焦點、重複確認或多尺寸；`_snapshot()` 記資料，不是截圖。

[ResourceLifecycle](../../../../tests/resource_lifecycle.gd) 驗既有 action／interceptor 等清理；新 modal、timer、全域訂閱與 owner 退出仍需對應斷言。不能由 All 綠燈推論新元件已被覆蓋；Smoke／Combat 沒有涵蓋所有場景或自動視覺比較，現有套件也不會自動涵蓋新增演出。

### 把新增 helper 真正接上

[runner](../../../../tools/test_game.py) 只接受 All／Dictionary／Combat（含 CombatVictory／CombatDefeat）／SaveLoad／Smoke／ResourceLifecycle，沒有 UI、Audio 或場景 suite。它複製 tests 頂層 `.gd`，**不會自動執行新 helper**；只存檔沒有 caller 就是零覆蓋。`--source-game` 只換 game 來源，tests 仍取 runner 所屬專案。候選副本方式見 [bootstrap](../content/bootstrap.md)。各篇提到的 `tests/ui_*_probe.gd` 都是後續實作建議，目前不存在。

靜態布局可建 tests/ui_layout_probe.gd（extends RefCounted），在 Smoke `_run()` 的 Root.add_child、兩次 process_frame 後、example mod probe 前，以 `load(get_script().resource_path.get_base_dir().path_join("ui_layout_probe.gd")).new()` 載入；呼叫其 `check_scene(game_root)`，把回傳的每筆 label／bool 交既有 `_check()`。若 helper 自己等待 layout，將方法設為 async 並由 caller await。需先建 helper 才插呼叫，不留無法載入的範例路徑。

互動／設施情境沿 Combat `_scenario()` 的起局、固定 seed 與 map button 模式另建，經真實 signal 開畫面，不手動設 visible、不直接 emit 勝利或 map_location_selected 假造流程。HUD／卡牌狀態 helper 可接在 Combat `_wait(_player_ready, ...)` 成功之後、既有 `_scenario()` 後續勝利出牌／`_defeat_flow()` 分支之前；只讀預覽或暫時選取／取消的 probe 須還原，不能改 HP／牌組破壞固定傷害斷言。需要新 suite 時連 runner 的 SUITE_CHOICES（及 ps1 包裝的 ValidateSet）、選擇分支、script mapping、PASS marker／結果 manifest 一起接，交測試入口 owner 整合。

helper 在 autoload ready 後才 runtime load，避免開頭 preload 提早解析遊戲全域 class。以既有 `_wait()` 型態等待 action idle／畫面狀態，有明確 timeout；不要固定睡一秒猜完成，也不要忽略 fail 繼續列 PASS。queue_free、Card 延後刷新與字級調整各自等待，最終移除 Root 並確認待選 action 沒有懸掛。

### A：HUD／目標／tooltip

HUD 數值、選目標／背景取消與 tooltip 的最小專項見 [互動狀態的 fixture](interaction-states.md#hud目標與-tooltip-的最小專項)。

### B：modal／獎勵的最小專項

用真實 ActionPickCards 與 CardData 候選；Hand、deck VIEW／SELECT、draft 是不同 consumer，各自驗零候選、選取／取消選取、足額、不合法牌、Confirm／Back／Skip 與隱藏。候選與取消零效果的設定見 [牌庫 VIEW／SELECT](screens/card-selection.md#專項-fixture-和-caller)，draft Skip／重開見 [獎勵與選牌](screens/rewards-selection.md#fixture-與驗收)，休息見 [rest-services](screens/rest-services.md#四種-fixture-的具體接法)。鍵盤／手把實作後，可背景驗 action 定義、focus neighbor 路徑、可聚焦元件、可取消／不可取消 handler 和一個事件不穿透兩層。

### C：版面、字型與證據層級

版面 fixture、虛擬 viewport、動畫基準見 [headless 幾何驗證](headless-geometry.md)。保留可用區、裁切、落腳與重開 run 斷言；不能用 headless 預設視窗值冒充目標尺寸。

## 命令與交接

從專案根跑 `python3 tools/test_game.py --suite Smoke`（共享場景／版面）、`--suite Combat`（戰鬥／獎勵 handler），清理變更加 `--suite ResourceLifecycle`；動到出牌路徑另依 [validation 的棋盤開關](../validation.md#棋盤開關兩種模式都要驗) 兩種模式都驗。讀 artifacts/verification 當次 results.json、engine／console log 與專項 assertion；通過須符合 [testing](../../testing.md)，不能只看 exit 0。

交接列出 source／test hash、fixture、候選根、suite／helper 呼叫位置、測過的狀態與尺寸、未驗視覺／輸入，讓下一位能重現而不依對話記憶。
