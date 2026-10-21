# vfx — 戰鬥特效接線與回收

[美術入口](../art-assets.md)｜[角色動畫](animation.md)｜[核實分析](../../../../analysis/slay-the-robot/design/vfx.md)

**何時用**：卡牌命中、格擋、狀態提示，或投射物、全畫面效果的製作與接線。
**何時不用**：只換角色動作走動畫；只換靜態圖走素材入口；改傷害規則走 [mechanics](../mechanics.md)。

現成入口、掛點、格擋／傷害分支與回收缺口以頁首分析為準；出牌事件鏈見 [presentation-delivery](../presentation-delivery.md#攻擊畫面命中與實際扣血)；素材檔案層依 [static-assets](static-assets.md)。

## Done when

任務紀錄存在效果 brief、資產／程式接點及來源，填妥觸發語意、時序、掛點、並發與取消策略。新增行為的背景斷言日誌記錄成功／拒絕／預覽／取消及回收結果；文件 lint 通過（見 [testing](../../testing.md)）。視覺與性能結果各有證據或明列待驗，不能以資源存在或 Smoke 通過代替。

## 流程

### 固定效果 brief 與語意

brief 放本次內容設計旁：效果 ID、來源卡／敵人／狀態、目標範圍、表達「出手／接觸／實際扣血／獲得格擋／破盾／狀態成立」中的哪一件事，以及形狀、色彩、強度、關鍵可見時刻。狀態善惡不只靠顏色；短效不應冒充仍有效的狀態標記。數值、費用與意圖仍由既有 UI 表達。

同時寫一次性或持續、開始／峰值／消失時間、每次出牌或每次命中幾份、多目標是逐一還是同步、重複觸發是疊加／刷新／取代／丟棄。填每目標與全場實例上限、最大存活時間、紋理尺寸／幀數／記憶體預估，以及目標機器的 CPU／GPU frame-time 預算與測量方式；這些是本次產品決策，框架沒有預設限流／性能保證。

### 選現成短效或新增機制

普通命中沿 `card_values.impact_vfx_animation_id` → ActionAttackGenerator → ActionCreateEffectAnimation → `create_effect_animation()`；新 AnimationData 註冊走 [bootstrap](../content/bootstrap.md)，逐格契約走動畫流程。獨立目標短效用該 Action 的 `impact_vfx_animation_id` 與 `target_override`，製作新素材不等於新增執行器。

格擋已有 ImageFade、受傷已有 TextFade；狀態圖示更新不等於施加狀態時會播 VFX。需要依實際結果（命中、完全格擋、等額破盾、狀態成功）選效果時，在對應結果點接線，避免額外通用命中特效造成雙播。

投射物飛行、持續光環、粒子、shader、螢幕震動和全畫面提示沒有現成通用管線；先走 mechanics／[UI](../ui.md) 增加 scene、owner、取消與完成契約。不要把 `impact_vfx_animation_id` 指向任意 PackedScene。投射物抵達是否才結算傷害屬玩法時序，須明定，不能用視覺時長暗改規則。

### 資產與掛點

brief 記來源畫布、輸出尺寸、中心／原點、alpha、混合方式與透明邊處理。逐格維持畫布與原點一致；預乘 alpha／加法等非預設材質必須有實際 scene／shader 接線。

現成 VFX 掛在目標 `Visible/AnimatedSprite2D/ImageFadeContainer`，用局部座標與 `animation_offset` 加隨機偏移（限制見 [分析](../../../../analysis/slay-the-robot/design/vfx.md#掛點與畫面層級)）。brief 記父層縮放、翻轉、裁切、z 順序與會遮到的血量／意圖／選擇區域。投射物改掛共同場景根要轉換兩端座標；全畫面效果要定獨立層級、viewport 尺寸及輸入穿透，不把 local position 當 global。

### 時點、多目標與預覽

VFX 先於傷害、instant 不等逐格播完、各自攔截與選目標等事實見上方事件鏈連結。需要精準接觸峰值與傷害對齊時，新增可測同步點，不只調 fps；要保證 VFX 與傷害落在同一目標，先建立共享的已決定目標契約。多段、致死、召喚／退場都驗實際次數，不以起始敵數乘攻擊數當必然結果。

卡牌預覽、意圖預覽與不可支付／無效目標拒絕路徑不得建節點或改實際狀態。預覽用 `_intercept_action(..., true)` 的查詢路徑，不能直接呼叫 VFX `perform_action()`。新 interceptor 的視覺副作用要遵守 preview_mode，並驗「查詢零次、成功預期次數」，不能只驗直接 spawn 可用。

### 所有權與取消

一次性 `animation_default` 必須有非空有效 frames、正 fps、非 loop，因為 AnimatedCombatEffect 只在 animation_finished 回收；缺 track、錯誤 loop／ID 要可診斷並無殘留。已生成節點由目標容器持有，`clear_all_actions()` 不取消已播放 VFX（回收缺口見 [分析](../../../../analysis/slay-the-robot/design/vfx.md#取消與回收邊界)）。

依 brief 決定取消時立即移除或限時結束；至少列目標死亡、狀態消失、combat_ended、run_ended、離樹及等待中取消。新增持續效果時，以目標／狀態實例記錄 handle，刷新與移除可重入；停止粒子、Tween、timer 與 signal，還原材質／相機，再釋放 owner。需等待完成時沿 [生命週期](../resource-lifecycle.md) 的 BaseAsyncAction 契約補取消 guard，取消後 callback 不得再派傷害。

### 專項驗證與視覺界線

先補 [分析列出的測試接點](../../../../analysis/slay-the-robot/design/vfx.md#專項測試接點)，再按 [validation](../validation.md) 選 Smoke、Combat、ResourceLifecycle；目前沒有 VFX suite。斷言真實 loader 的 SpriteFrames、節點增減、目標身份、順序、取消後零次新效果及退出日誌，保留 timeout；先斷言產品自行回收，再清 fixture。

視覺與性能項目（實際尺寸與最壞並發下的透明邊、峰值對齊、遮擋、無反覆明暗閃爍、資訊可辨、強光／震動可停用並保留替代提示、目標環境量測）列在同一分析節；不能靠逐格檔案存在宣稱無閃爍，全畫面提示不可搶輸入。未觀察項依 [證據層級](../ui/verification.md#證據層級與判讀) 填待驗。

## 交接

交內容／機制 agent：效果 ID、觸發結果、順序與取消策略；交美術／UI agent：來源／輸出、掛點、座標與安全區；交驗證 agent：情境、預期次數、deadline、日誌與未驗項。同步本篇與分析；清單紀錄方式同 [static-assets](static-assets.md#交接)。
