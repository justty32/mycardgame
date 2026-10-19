# art-assets — 美術方向、靜態素材、角色動畫與特效

[遊戲開發入口](README.md)｜[素材子流程](art-assets/README.md)｜[UI 接線](ui.md)｜[內容接線](content.md)

把需求轉成可追溯、可整合的素材；來源事實在 [美術製作分析](../../../analysis/slay-the-robot/design/art-production.md)，時序與畫面接點在 [呈現分析](../../../analysis/slay-the-robot/design/presentation.md)。

**何時用**：決定原創美術方向、製作或替換卡圖／角色圖／圖示／背景、角色動畫與 VFX、批次風格統一。

**何時不用**：版面／字型／輸入走 [UI](ui.md)，音訊走 [audio](audio.md)，規則／數值走 [mechanics](mechanics.md)。工具可用不構成製作新內容的需求。

## Done when

任務 brief、來源與版本紀錄及需求中的素材檔存在；交付紀錄填有內容 ID、使用欄位／節點、尺寸／原點、整合路徑、檢查結果與未驗項。實際執行的解碼／接線檢查有退出碼與證據；未進行視覺驗收者明列「素材／接線完成，視覺待驗」。文件變更有 strict lint 結果，不以文件通過代替素材通過。

## 流程

### 先取得使用規格

先讀 [使用者邊界](../common/user.md)，依 [子流程入口](art-assets/README.md) 先選卡牌、戰鬥人物、介面套件或環境背景的用途契約，查實際 consumer、狀態及尺寸來源。方向未定先走 [style-guide](art-assets/style-guide.md)，已有定版則直接走 [static-assets](art-assets/static-assets.md)。實際場景尺寸是約束，框架占位圖不是原創美術方向。

### 選擇製作方式並保留來源

點陣插畫依當前可用 imagegen skill；既有 SVG／程式圖形保留原格式。來源／作者／使用條件、母稿與派生檔雜湊、工具及可取得版本一併記錄；方法在 static-assets。無能力或使用條件未釐清時交明確缺項，不假造素材或模型資訊。外部研究參考的角色不授予其素材使用權。

### 命名、載入與替換

靜態素材依 static-assets 的消費端分流；完整專案相對路徑、外部 loader 與打包資源不可混用。角色選單 icon、圖鑑圖片與戰鬥動畫是不同入口；更動尺寸／裁切與命中範圍交 UI，mod 註冊交 content。

### 動畫與特效

角色狀態／逐格動畫接 [animation](art-assets/animation.md)，命中、投射物與一次性特效接 [vfx](art-assets/vfx.md)。靜態角色母稿可共用風格版本，但不代表動畫或戰鬥時間線已完成；不可用換圖偷偷更改傷害節奏。

### 驗收與交接

先檔案與引用，再目標 loader／場景，再視覺；各層記錄分開。現在禁止桌面／視窗／UI／截圖／焦點、GUI、聲音播放與操作既有程序；只有當前任務明確允許的檔案及背景檢查可執行。沒有引擎授權就只記待跑檢查，不啟動 Godot。成品匯出另驗 external 打包，現有 Import 不涵蓋。

## 交接

### 一張新卡的跨領域接線

先由 [內容 bootstrap](content/bootstrap.md) 固定 mod、card 與取得入口，再沿 `CardData.card_texture_path → FileLoader.load_texture → Card.update_card_display → CardTexture` 接圖。卡名、費用與規則文字由 UI 提供。音效另由 [audio](audio.md) 定義成功出牌／命中時機並查 action 陣列執行順序。

同一交付紀錄串起內容 ID、圖／音路徑、顯示框、事件與驗收。既有 Smoke 不會自動驗任意新素材；依 [validation](validation.md) 將目標 loader 非 fallback、Card 等待刷新後的 texture／文字等斷言接入實際 suite。音效成功一次／拒絕與預覽零次需無聲專項；背景通過仍留下視覺／聽感待驗。

交 UI 最終尺寸、原點、安全區及狀態變體；交內容資料欄位與路徑；交動畫／VFX 共用母稿與風格版本。批次紀錄超過 1 KB 依 [data-files](../common/data-files.md) 用 `wf-table/1`，不複製清單到多篇 md。
