# 靜態素材：從批次製作到資料與場景接線

[美術入口](../art-assets.md)｜[風格版本](style-guide.md)｜[核實來源](../../../../analysis/slay-the-robot/design/art-production.md)

本篇是各用途篇（[cards](cards.md)、[combatants](combatants.md)、[environments](environments.md)、[interface-assets](interface-assets.md)）共用的製作規則單一來源：來源與授權、母稿→輸出與 hash、完整解碼、載入路徑與快取、fallback、匯出及批次紀錄。用途篇只寫自己的 consumer、尺寸、狀態、缺失接點與專項驗收；風格版本由 [style-guide](style-guide.md) 管。

**何時用**：依既定方向製作卡圖、角色立繪／頭像、圖示及背景，或替換同一批素材；只有單張既有圖片且用途契約已固定時，可直接只用本篇。**何時不用**：角色狀態／切格走 [animation](animation.md)，命中／投射物走 [vfx](vfx.md)，純排版走 [UI](../ui.md)。

## Done when

交付的素材、母稿或可定位來源、brief 及版本紀錄存在；紀錄填有使用權、風格版本、內容 ID→欄位／節點→輸出檔、SHA-256、實際尺寸與驗收結果。每張圖的解碼／尺寸／引用檢查有結果；接入需求另有目標 loader／場景證據。視覺與匯出未驗者逐項註明，不能只用 PNG 標頭或 Smoke PASS 宣稱完成。

## 流程

### 先定位使用端再決定畫布

從 [來源分析](../../../../analysis/slay-the-robot/design/art-production.md) 開對應原始碼與 scene。對每個待交付內容 ID 記用途、最小顯示尺寸、來源畫布、裁切方式、安全區、透明／不透明要求、朝向／原點、狀態變體與輸出格式。安全區以畫布像素或比例明確表示；不能只寫「留白適當」。新尺寸需連同容器、父節點 scale、文字與命中區評估。

### 製作與來源保存

插畫／照片／紋理等點陣需求，先讀當前 imagegen skill 並使用其支援流程；編輯既有 SVG、程式圖形或圖示系統則維護原格式。手繪、委製或現成素材留作者、原始來源、取得日期與使用條件；外部研究參考的角色不授予其素材使用權。需要的工具不可用或使用條件未釐清時，列明欠缺能力及可交接規格，不默默改成不同交付媒材，也不把候選素材說成完成、不假造模型資訊。

母稿置於專案約定的原創設計位置，遊戲實際引用的輸出置於 mod 的 `sprites/` 分類目錄。檔名用穩定內容 ID 與用途，避免以生成序號作內容 ID。記錄母稿→裁切／縮放／去背等處理→輸出，以及實際工具／版本、參考檔 hash；未知模型／seed 寫未提供。輸出檔每次變更更新 hash，重算其派生圖。檔案版本不等於風格版本，兩者都保留。多處共用同一圖時由一個母稿版本派生，改動須通知全部使用端重驗。

先完成代表樣本再批次；檢查透明背景是真透明而非棋盤格畫進圖中，主體沒有切斷、四周留白一致。機械檢查只能證明像素／尺寸，審美與辨識度仍需視覺證據。

### 整合：完整路徑與可重現替換

外部欄位填 `external/mods/<mod_id>/sprites/<用途>/<內容_id>.png` 的完整專案相對路徑；角括號是待替換參數。它不是相對資料 JSON。新增 mod 與資料 patch 包裝依 [bootstrap](../content/bootstrap.md)；母稿與未採用候選不放進會掃 JSON 的資料目錄。外部 loader 不會依 atlas 座標自動切圖；需要 AtlasTexture／切片的新使用端列入 UI 工程。

FileLoader 依完整路徑快取，不以既有程序熱換檔後的畫面作證據。需要引擎驗證時另開新的隔離背景程序。scene 的 `ext_resource`／theme 則走 Godot 匯入與 UID；外部 ImageTexture 不靠 `.import` 完成同一套行為。保留前版與欄位改動對照，方便退回已驗版本，不覆蓋使用者其他素材。

### 驗收層次與失敗定位

依序分層記錄：檔案與引用 → 目標 loader／場景 → 視覺 → 匯出。先用現有可用的無視窗圖像解碼工具完整讀取每張檔案，核對格式、實際長寬、alpha 像素範圍及是否全透明；僅讀 IHDR 要註明是標頭檢查。工具缺失時明列未解碼。以 `sha256sum` 留輸出身分（Windows 用 `Get-FileHash -Algorithm SHA256`），再查引用路徑大小寫、內容 ID 與缺檔。不得把 alpha 通道存在當作透明邊緣正確。

接入任務需在 [bootstrap](../content/bootstrap.md) 的 helper 接線方式加入目標斷言，依 [validation](../validation.md) 跑已授權套件；沒有現成「素材 suite」，新增 helper 必須真的被呼叫（見 [helper 接線](../ui/verification.md#把新增-helper-真正接上)）。目標 loader 結果不能是 MISSING_TEXTURE（fallback 只保底，不是採用成功），且尺寸非零並符合輸出。既有 Smoke 只表示其既定斷言通過。

可做視覺驗收時，對最小顯示尺寸與實際背景檢查可辨識性、裁切、透明邊、模糊、色彩語意、文字遮擋與批次一致性；背景斷言與視覺的分界、未執行時如何標記見 [證據層級](../ui/verification.md#證據層級與判讀)，不借用其他任務的成功紀錄。發行包另驗 `exported` feature 與 exe 旁 external；現有 Import 不涵蓋，不能引用開發載入結果代替。

## 交接

交付紀錄為每個資產保留來源／權利、風格與母稿版本、輸出 hash、接點、檢查證據及待驗狀態；各用途篇沿用這一份，不另造。批次同質紀錄大於 1 KB 時依 [資料契約](../../common/data-files.md) 建 `wf-table/1`，以 tabledb 讀寫；只在真有資產時建立紀錄，不建空模板。UI owner 接最終尺寸／原點／安全區／狀態變體／容器與命中責任，內容 owner 接 ID／資料欄位與路徑，動畫／VFX owner 接共用母稿、風格版本、時間與原點。完整日誌留 artifacts；可重用的來源事實回分析，操作接點回本流程。
