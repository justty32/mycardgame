# 場景與環境：戰鬥、節點與主選單背景

[素材子流程](README.md)｜[共同製作](static-assets.md)｜[背景來源](../../../../analysis/slay-the-robot/design/art-production.md#場景背景幾何與前後層)

**何時用**：替戰鬥、事件地點、休息／商店場景或主選單製作背景與前後層套件。**何時不用**：地圖拓撲／遭遇分配走 [level-design](../level-design.md)，介面面板走 [interface-assets](interface-assets.md)，動態全畫面效果走 [vfx](vfx.md)。

## Done when

背景 brief、各層輸出與合成／裁切規格存在；紀錄填入 Act／Location／Event 欄位或 scene 節點、畫布及顯示框、遮擋安全區、版本與實際檢查結果。接入需求有覆寫／空值／切換的專項證據；新建前景、主選單圖層或視差尚未實作時標待接線。未視覺驗收不得宣稱角色或 UI 可讀。

## 流程

### 先確定空間與使用端

從 [Combat._update_background](../../../../game/scripts/ui/Combat.gd) 與 [Root.tscn](../../../../game/scenes/Root.tscn) 查真正消費者。Act 提供較廣預設，非空 Location 覆寫它，非空 Event 最後覆寫；決定本次素材應覆蓋哪個範圍再填欄位，避免只想改單一頭目場景卻改全幕。三者皆空時目前沒有清圖分支，切換策略交 UI／機制 owner 處理並驗證。

戰鬥及部分非戰鬥節點共用 Combat 場景，但 ShopOverlay／RestOverlay／DialogueOverlay 有自己的背景層；Act 圖不等於商店面板 skin。對話主插圖另由 state path 載入，走 interface-assets。TitleScreen/Background 則是 ColorRect，沒有同一套 Act 路徑；主選單插畫需新增或改裝 scene 圖層，不往 Act 填值。

### 取得幾何與安全區

以 Root 的 1200×700 Combat 及滿區 BackgroundButton 作目前基準，讀其 stretch_mode 與實際父容器，再記母稿比例與裁切／拉伸策略。不要把 viewport 當成唯一輸出規格；如果目標範圍／縮放改動，先交 UI 決定 letterbox、裁切或延展，再產出相應寬幅安全區。

先標玩家／敵人活動區、血條／意圖、頂部 HUD、底部手牌與 modal 出現時的文字區。現有 Player 在 `(200,336)` 起、EnemyContainer 在 `(568,256)` 起、Hand 在 `(168,632)` 起；這些是容器起點，不是角色所有動畫的外接矩形。安全區須納入動畫伸展、手牌 hover 與目標提示，由 combatants／animation／UI owners 提供最大範圍；不能照靜止姿勢挖一個窄洞。

背景焦點、地平線、光源與前景遮擋要配合角色版本；身體周圍保留可辨識亮度與細節密度，UI 字區避免高頻細節。主選單另按標題與按鈕實際範圍避讓，不把戰鬥人物留白直接沿用到主選單。

### 決定單張或多層交付

既有外部背景路徑只載一張 Texture2D 到 BackgroundButton。若需求可由單張完成，就合成背景輸出並保留母稿；若需前景遮擋、動態雲霧或視差，分遠景／中景／前景是設計交付選擇，並非框架已存在的多層 API。先指定每層的 scene owner、z／順序與是否隨鏡頭動，交 UI／VFX 實作後才標已整合。

透明前景按 scene 座標交同尺寸畫布或附明確 offset，切片交 rect／拼接邊界，平鋪圖交重複方向與接縫規格。不能因為只畫一小塊就忘記其原點，造成前景遮住手牌。背景按鈕仍處理左右鍵；新增裝飾層要由 UI 保留輸入穿透，不能直接覆蓋成滿版攔截按鈕。

### 製作、版本與切換

沿 [style-guide](style-guide.md) 固定同一區域的材質、色調、光源與構圖語彙；區域／日夜／事件變體只在需求存在時製作。母稿分層保留來源及權利，輸出及合成參數依 static-assets 留 hash；背景與角色共同調色時提高風格版本並通知相關素材重驗。逐層輸出不以檔名順序代替正式合成順序。

資料型背景放 mod sprites 並填完整專案相對路徑，scene 背景則走 ext_resource／UID。需要切片／AtlasTexture 的新使用端列入 UI 工程，不假設外部 loader 會自動處理 atlas。正式引用只切至已解碼與版本一致的檔案，保留前版路徑／資料修改對照供回退。

### 專項驗收

先驗每層完整解碼、長寬／alpha 與輸出 hash；再針對 Act-only、Location override、Event override、全空與連續跨節點切換建立 loader／texture 斷言。主選單及新增前景另驗其實際 scene 節點和繪圖／輸入順序，不以戰鬥背景測試代替。多層需求須驗離場與重入後沒有重複層或殘留。

實際視覺需在玩家／最大敵人、滿手牌、意圖提示、長文 modal 等需求情境檢查對比、裁切與遮擋；rect 斷言只能證明配置。當前不啟動 Godot、不開 GUI／桌面／視窗／截圖或操作焦點，因此本次只補流程與靜態來源，視覺與 runtime 明列待驗。外部背景發行還須依共同流程驗成品 external 與 exported feature。

## 交接

交 UI 每層來源畫布、offset、合成順序、拉伸／裁切、輸入責任與安全區；交關卡 owner Act／Location／Event ID 與覆寫範圍；交人物與 VFX owners 光源、活動區與遮擋約束。未實作的多層／視差／動態背景是具體下一步，不當成素材缺檔；版本紀錄沿共同流程保留一份。
