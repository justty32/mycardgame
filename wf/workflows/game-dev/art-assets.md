# art-assets — 美術方向、靜態素材、角色動畫與特效

[遊戲開發入口](README.md)｜[整套畫面](scene-pack.md)｜[UI 接線](ui.md)｜[內容接線](content.md)

把需求轉成可追溯、可整合的素材；來源事實在 [美術製作分析](../../../analysis/slay-the-robot/design/art-production.md)，時序與畫面接點在 [呈現分析](../../../analysis/slay-the-robot/design/presentation.md)。操作邊界見 [user.md](../common/user.md#桌面與程序邊界)。

**何時用**：決定原創美術方向、製作或替換卡圖／角色圖／圖示／背景、角色動畫與 VFX、批次風格統一；或已從 game-dev 分派美術、動畫或特效工作，需要由具體用途走到可接入的素材套件。

**何時不用**：版面／字型／輸入與純 UI 排版走 [UI](ui.md)，音訊走 [audio](audio.md)，規則／數值與傷害時機走 [mechanics](mechanics.md)。工具可用不構成製作新內容的需求。

## Done when

任務 brief、來源與版本紀錄及需求中的素材檔存在；交付紀錄填有內容 ID、使用欄位／節點、尺寸／原點、整合路徑、檢查結果與未驗項，並分別列出方向、資產、接線、視覺及尚缺能力的狀態。實際執行的檢查有退出碼與證據；未進行視覺驗收者明列「素材／接線完成，視覺待驗」。跨領域依賴有檔案、owner 與下一步，不以未產出的資產填入完成欄。文件 lint 通過（見 [testing](../testing.md)），但文件通過不代表素材通過。

## 依用途選子流程

先問這次在做哪個完整使用面，而不是只問 PNG 或動畫。從下表選用途取得實際 consumer、尺寸與狀態契約（實際場景尺寸是約束，框架占位圖不是原創美術方向）；方向未定先走風格方向，再沿靜態素材共同流程完成來源、母稿、輸出與分層驗收，最後回用途流程做專項接線驗收。整個畫面含互動、動態與聲音時，由 [scene-pack](scene-pack.md) 協調共同版本和事件，不以圖像包代替整套畫面。

<!-- wf-nav -->
| 任務 | 入口 |
|---|---|
| 卡框、卡圖、卡背候選、費用、稀有度、裝飾與可用狀態 | [卡牌視覺套件](art-assets/cards.md) |
| 玩家／敵人／頭目、頭像／圖鑑、角色動畫母稿 | [戰鬥人物外觀套件](art-assets/combatants.md) |
| 對話、商店／休息、獎勵、地圖、選單的圖像與 skin 套件 | [介面圖像套件](art-assets/interface-assets.md) |
| 戰鬥／節點／主選單背景、前後層與安全區 | [環境與場景](art-assets/environments.md) |
| 上述用途共用的方向、跨類別代表樣本、風格版本 | [風格方向](art-assets/style-guide.md) |
| 上述用途共用的來源／作者／授權、母稿與派生輸出、hash、載入路徑、分層驗收與批次紀錄 | [靜態素材共同流程](art-assets/static-assets.md) |
| idle／attack／death、逐格規格、狀態與播放生命週期 | [角色動畫](art-assets/animation.md) |
| 按鈕／卡牌／選單／modal 的狀態轉場，以及對話、設施、選牌與地圖的整段演出 | [演出共通契約與用途](art-assets/motion/README.md) |
| 命中／格擋／狀態、投射物／全畫面、預覽拒絕取消與回收 | [特效](art-assets/vfx.md) |

靜態角色母稿可共用風格版本，但不代表動畫或戰鬥時間線已完成；不可用換圖偷偷更改傷害節奏。出牌事件鏈（action 執行序、媒體 action 不等待、命中與扣血分離）見 [presentation-delivery](presentation-delivery.md)。

## 交接

### 一張新卡的跨領域接線

先由 [內容 bootstrap](content/bootstrap.md) 固定 mod、card 與取得入口，再沿 `CardData.card_texture_path → FileLoader.load_texture → Card.update_card_display → CardTexture` 接圖。卡名、費用與規則文字由 UI 提供。音效另由 [audio](audio.md) 定義成功出牌／命中時機，並查 action 陣列的執行順序。

同一交付紀錄串起內容 ID、圖／音路徑、顯示框、事件與驗收。既有 Smoke 不會自動驗任意新素材；依 [validation](validation.md) 將目標 loader 非 fallback、Card 等待刷新後的 texture／文字等斷言接入實際 suite。音效「成功一次／拒絕與預覽零次」需要無聲專項；背景通過後的判讀見 [證據層級](ui/verification.md#證據層級與判讀)。

### 共用紀錄

用途流程不複製共通資產清單：沿用同一份風格版本與來源／母稿／輸出紀錄（[static-assets](art-assets/static-assets.md#交接)），各篇只交接實際消費端與未實作項。
