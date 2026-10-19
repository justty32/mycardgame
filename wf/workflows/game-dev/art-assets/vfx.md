# vfx — 戰鬥特效接線與回收

[素材入口](README.md)｜[角色動畫](animation.md)｜[核實分析](../../../../analysis/slay-the-robot/design/vfx.md)

**何時用**：卡牌命中、格擋、狀態提示，或投射物、全畫面效果的製作與接線。
**何時不用**：只換角色動作走動畫；只換靜態圖走素材入口；改傷害規則走 [mechanics](../mechanics.md)。

## Done when

任務紀錄存在效果 brief、資產／程式接點及來源，填妥觸發語意、時序、掛點、並發與取消策略。新增行為的背景斷言日誌記錄成功／拒絕／預覽／取消及回收結果；文件 strict lint 回傳 0。視覺與性能結果各有證據或明列待驗，不能以資源存在或 Smoke 通過代替。

## 流程

### 固定效果 brief 與語意

先讀分析確認現成能力。brief 放本次內容設計旁：效果 ID、來源卡／敵人／狀態、目標範圍、表達「出手／接觸／實際扣血／獲得格擋／破盾／狀態成立」中的哪一件事，以及形狀、色彩、強度、關鍵可見時刻。狀態善惡不只靠顏色；短效不應冒充仍有效的狀態標記。數值、費用與意圖仍由既有 UI 表達。

同時寫一次性或持續、開始／峰值／消失時間、每次出牌或每次命中幾份、多目標是逐一還是同步、重複觸發是疊加／刷新／取代／丟棄。填每目標與全場實例上限、最大存活時間、紋理尺寸／幀數／記憶體預估，以及目標機器的 CPU／GPU frame-time 預算與測量方式；這些是本次產品決策，框架沒有預設限流／性能保證。

### 選現成短效或新增機制

普通命中沿 `CardData.card_values.impact_vfx_animation_id` → `ActionAttackGenerator` → `Scripts.ACTION_CREATE_EFFECT_ANIMATION` → `BaseCombatant.create_effect_animation()`。新 AnimationData 註冊走 [內容 bootstrap](../content/bootstrap.md)，逐格來源與資料契約走動畫流程。若只有獨立目標短效，使用該 Action 的 `impact_vfx_animation_id` 與 `target_override`，不要把製作新素材等同新增執行器。

格擋已有 `Player/Enemy.add_block()` 的 ImageFade；受傷已有 TextFade。狀態 UI 的圖示更新不等於施加狀態時會播放 VFX。需要依實際結果選命中、完全格擋、破盾或狀態成功效果，必須在對應結果點接線，避免額外通用命中特效造成雙播。確切訊號與分支見分析。

投射物飛行、持續光環、粒子、shader、螢幕震動和全畫面提示沒有現成通用管線；先走 mechanics／[UI](../ui.md) 增加 scene、owner、取消與完成契約。不要把 `impact_vfx_animation_id` 指向任意 PackedScene，也不要假定引擎能做就等於框架已支援。投射物抵達是否才結算傷害屬玩法時序，須明定，不能用視覺時長暗改規則。

### 資產與掛點

brief 記來源畫布、輸出尺寸、中心／原點、alpha、混合方式與透明邊處理。逐格維持畫布與原點一致；確認真正透明像素，預乘 alpha／加法等非預設材質必須有實際 scene／shader 接線。外部 PNG 經 FileLoader 載入與快取，匯入設定不能代替解碼與實際引用驗證。

現成 VFX 掛在目標 `Visible/AnimatedSprite2D/ImageFadeContainer`，使用局部座標與 `animation_offset` 加隨機偏移；沒有全畫面定位，也沒有自動來源到目標的飛行軌跡。記錄父層縮放、翻轉、裁切、z 順序與會遮到的血量／意圖／選擇區域。投射物若改掛共同場景根，要明確轉換兩端座標；全畫面效果需獨立層級、viewport 尺寸及輸入穿透策略，不能把子節點 local position 當 global position。

### 時點、多目標與預覽

`ActionHandler.add_actions()` 預設 stack 後項先執行；現有 generator 將 VFX 追加在 Attack 後，因此 VFX 先生成，傷害後執行。它是 instant，只等下一個 process frame，不等逐格播完；`time_delay` 不是命中事件時間。需要精準接觸峰值與傷害對齊時，新增可測同步點，不只調 fps。

VFX 與 Attack 分別攔截、分別解析目標；拒絕傷害不保證先前 VFX 沒播。ALL_ENEMIES 依每次 action 的存活目標產生，RANDOM_ENEMY 更可能各抽一次；要保證同一目標，先建立共享的已決定目標契約。多段、致死、召喚／退場都驗實際次數，不以起始敵數乘攻擊數當必然結果。

卡牌預覽、意圖預覽與不可支付／無效目標拒絕路徑不得建節點或改實際狀態。預覽用 `_intercept_action(..., true)` 的查詢路徑，不能直接呼叫 VFX `perform_action()`。新 interceptor 的視覺副作用要遵守 preview_mode，並驗「查詢零次、成功預期次數」，不能只驗直接 spawn 可用。

### 所有權與取消

一次性 `animation_default` 必須有非空有效 frames、正 fps、非 loop；AnimatedCombatEffect 只在 animation_finished 回收，不跟 next animation 轉移。缺 track、錯誤 loop／ID 要可診斷並無殘留；現碼有缺口，見分析。已生成節點由目標容器持有，`clear_all_actions()` 只清執行工作，沒有取消已播放 VFX。

依 brief 決定取消時立即移除或讓短效限時結束；至少列目標死亡、狀態消失、combat_ended、run_ended、離樹及等待中取消。持續效果以目標／狀態實例記錄 handle，刷新與移除可重入；停止粒子發射、Tween、timer 與 signal，還原改過的材質／相機，再釋放 owner。這些是新增機制的要求，並非現成 API。若需等待完成，沿 [生命週期](../resource-lifecycle.md) 的 BaseAsyncAction 契約補取消 guard，禁止取消後 callback 再派傷害。

### 專項驗證與視覺界線

先補 [分析列出的測試接點](../../../../analysis/slay-the-robot/design/vfx.md#專項測試接點)，再按 [validation](../validation.md) 選 Smoke、Combat、ResourceLifecycle；目前沒有 VFX suite。斷言真實 loader 的 SpriteFrames、節點增減、目標身份、順序、取消後零次新效果及退出日誌，保留 timeout；先斷言產品自行回收，再清 fixture。

在允許視覺檢視時，以實際尺寸和最壞並發驗透明邊、軌跡／峰值時點、遮擋、層級與縮放。採無反覆明暗閃爍的效果；不能靠逐格檔案存在宣稱無閃爍或視覺安全。血量、格擋數、敵意圖及選牌必須持續可辨；全畫面提示不可搶輸入，震動／強光需可停用且保留形狀或文字替代提示。多實例疊加也要驗，不只單播。性能結論須有目標環境量測，headless 不能證明 GPU 或視覺品質。

目前禁止桌面／視窗／UI／截圖／焦點／GUI 與聲音操作，不干預既有程序；只進行任務允許的檔案與背景檢查。若僅文件任務，不啟動 Godot。未能觀察的呈現、無閃爍、可辨性及性能均填待驗。

## 交接

交內容／機制 agent：效果 ID、觸發結果、順序與取消策略；交美術／UI agent：來源／輸出、掛點、座標與安全區；交驗證 agent：情境、預期次數、deadline、日誌與未驗項。同步本篇與分析，清單超過 1 KB 按 [資料契約](../../common/data-files.md) 落資料檔。
