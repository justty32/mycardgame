# scene-pack — 完整畫面的圖像、UI、聲音與動畫交付

[遊戲開發](README.md)｜[美術用途](art-assets.md)｜[UI 用途](ui.md)｜[音訊](audio.md)｜[出牌時序](presentation-delivery.md)

**何時用**：使用者要做完整戰鬥畫面、敵人／頭目、對話、商店、休息、獎勵選牌、地圖、選角或結算；需要整套呈現而非只換一張圖。
**何時不用**：單一資產替換走美術／音訊子流程；新增價格、獎勵、對話後果或戰鬥規則走 [內容](content.md)／[關卡](level-design.md)／[mechanics](mechanics.md)。本流程不決定未定產品規則。

## Done when

交付記錄填齊 UI 組成、圖像包、聲音 cue、動畫時序、資料來源、退出責任與驗收結果；採用檔案和引用存在，跨領域使用同一版本。適用專項有結果及未驗範圍；文件 lint 通過（見 [testing](../testing.md)）。

## 流程

### 以完整玩家任務開場

第一步由 Root 找畫面 scene／script，寫玩家進入、資訊、操作和完成去向。指定場景整合 owner，領域 owner 管各自資產和 consumer。頭目階段、售價、退費、選牌數量等未定需求保持既有行為，不由呈現 agent 補規則。

畫面契約包含 UI 版面／文字／互動／遮罩，圖像背景／主體／框／圖示／狀態／安全區／版本，聲音 cue 語意／唯一接點／次數／bus／停止／無聲替代，動畫開始／峰值／完成／輸入阻擋／中斷清理；再綁資料 ID、進出 scene 的 owner、fixture 與觀察點。批次表超過 1 KB 依 [資料契約](../common/data-files.md) 保存，不新增遊戲 schema。

列可操作、不可用／空資料、等待、返回／離場和重入狀態，區分既有 consumer、本次新增和待需求。圖像尺寸取自真實節點，不烘規則文字；聲音／動畫依結果事件觸發，按下 button 不等於購買或選項成功。

### 依完整用途分工

以下每列是一個完整交付包。點進各領域子篇取得實際欄位、scene／script、狀態與驗證骨架；場景 owner 將其合成同一份契約。各包背景另用 [場景與環境](art-assets/environments.md)，共同樣式與版本沿美術入口；VFX 仍沿 [特效](art-assets/vfx.md)。

<!-- wf-nav -->
| 完整任務 | UI／狀態 | 圖像套件 | 聲音 cue | 動畫／轉場 |
|---|---|---|---|---|
| 卡框＋卡圖＋互動狀態，連同戰鬥 HUD／目標／tooltip | [戰鬥](ui/screens/combat.md) | [卡牌](art-assets/cards.md)、[介面](art-assets/interface-assets.md) | [戰鬥聲包](audio/combat-cues.md) | [卡牌動態](art-assets/motion/cards.md)、[出牌時序](presentation-delivery.md) |
| 一般敵人＋頭目：身體、意圖、狀態、選取區、死亡與圖鑑 | [戰鬥](ui/screens/combat.md) | [人物敵人](art-assets/combatants.md) | [戰鬥聲包](audio/combat-cues.md) | [人物狀態](art-assets/animation.md)、[演出契約](art-assets/motion/README.md) |
| 對話：敘事圖／頭像、文字、選項、失敗理由及進出 | [對話](ui/screens/dialogue.md) | [介面圖像](art-assets/interface-assets.md) | [對話聲包](audio/dialogue-cues.md) | [對話演出](art-assets/motion/dialogue-shop.md) |
| 商店購買與休息服務兩畫面，各含不可用／結果／返回 | [商店與休息](ui/screens/shop-rest.md) | [介面圖像](art-assets/interface-assets.md)、[商品卡](art-assets/cards.md) | [商店](audio/shop-cues.md)、[休息](audio/screen-cues.md) | [商店演出](art-assets/motion/dialogue-shop.md)、[休息演出](art-assets/motion/rest-selection.md) |
| 獎勵列＋draft＋牌庫選牌：暫選、確認／Skip／Back及取得結果 | [獎勵選牌](ui/screens/rewards-selection.md) | [卡牌](art-assets/cards.md)、[介面](art-assets/interface-assets.md) | [畫面聲包](audio/screen-cues.md) | [獎勵演出](art-assets/motion/rewards-map.md)、[牌庫選牌演出](art-assets/motion/rest-selection.md) |
| 選角起局→地圖選點→勝／敗結算返回，三畫面均交付 | [地圖](ui/screens/map.md)、[選角與結算](ui/screens/menus-collection.md) | [人物](art-assets/combatants.md)、[介面](art-assets/interface-assets.md) | [畫面聲包](audio/screen-cues.md) | [選角與結算轉場](art-assets/motion/menus.md)、[地圖演出](art-assets/motion/rewards-map.md) |

卡牌／戰鬥包用同一 CardPlayRequest 串資料結果和媒體；成功、命中與取消按出牌時序定義。敵人包分戰鬥身體與圖鑑、UI選取區；頭目未定的轉階段規則不因素材需求而新增。

對話、商店、休息各有不同的結果／重建／退出 owner，選項或交易接受不等於效果完成；不要由通用按鈕音取代領域結果。獎勵選牌須區分暫選、取得與返回，既有 Skip／Back 的資料結果依 action 配置，不能假定取消一律效果零次。相關來源陷阱和 fixture 前提集中在上述子篇。

最後一包以完整旅程驗三畫面，不能只驗地圖便整包通過。商店／休息也必須兩者各自具備完整的七項交付內容，也就是 Done when 所列的 UI 組成、圖像包、聲音 cue、動畫時序、資料來源、退出責任與驗收結果，不能由其中一個畫面代表另一個。各畫面的空資料、不可用、等待、退出及重入要分別列結果，跨畫面音樂和持續效果則由整合 owner 確認接手／停止，不讓兩個 owner 同播。

### 串行整合與驗收

先交代表資產與接線，由場景 owner 用同一 fixture 串玩家任務，驗結果唯一發生再擴變體。缺素材指定已驗回退或停用純呈現接點；MISSING fallback 不是完成。UI 重建不得重複 connect／cue，持續音效、Tween、timer、listener 都需離場 owner。

先驗來源／hash／解碼／ID／scene 引用；實作後按 [UI 驗證](ui/verification.md) 與 [validation](validation.md) 接 helper，驗資料、播放計數、狀態和清理。背景斷言不等於視覺驗收：視覺、聽感與實際輸入需要 GUI，未執行時明列未驗（操作邊界見 [user.md](../common/user.md#桌面與程序邊界)）。

## 交接

交付場景契約與領域產物指標；實碼問題交 owner，產品未決項保留。冷接手須以完整場景提出開工計畫，不能由技術入口存在推論用途已覆蓋。
