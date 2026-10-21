# 場景與環境：戰鬥、節點與主選單背景

[美術入口](../art-assets.md)｜[共同製作](static-assets.md)｜[背景來源](../../../../analysis/slay-the-robot/design/art-production.md#場景背景幾何與前後層)

**何時用**：替戰鬥、事件地點、休息／商店場景或主選單製作背景與前後層套件。**何時不用**：地圖拓撲／遭遇分配走 [level-design](../level-design.md)，介面面板走 [interface-assets](interface-assets.md)，動態全畫面效果走 [vfx](vfx.md)。

覆寫順序、節點幾何與 overlay 背景層見頁首來源（含「背景覆寫與空值」節）及 [戰鬥畫面](../ui/screens/combat.md)；共同製作規則依 [static-assets](static-assets.md)。

## Done when

背景 brief、各層輸出與合成／裁切規格存在；紀錄填入 Act／Location／Event 欄位或 scene 節點、畫布及顯示框、遮擋安全區、版本與實際檢查結果。接入需求有覆寫／空值／切換的專項證據；新建前景、主選單圖層或視差尚未實作時標待接線。未視覺驗收不得宣稱角色或 UI 可讀。

## 流程

### 先確定範圍與使用端

Act→Location→Event 依序覆寫且空路徑不清前圖；先決定本次素材應覆蓋哪個範圍再填欄位，避免只想改單一頭目場景卻改全幕，需要清圖時切換策略交 UI／機制 owner。商店／休息／對話 overlay 有自己的背景層，Act 圖不等於面板 skin；對話主插圖走 interface-assets。主選單背景是 ColorRect，插畫需新增或改裝 scene 圖層，不往 Act 填值。

### 取得幾何與安全區

以目前 1200×700 Combat 與滿區 BackgroundButton 的拉伸設定為基準，記母稿比例與裁切／拉伸策略；不要把 viewport 當成唯一輸出規格。目標範圍／縮放改動時，先交 UI 決定 letterbox、裁切或延展，再產出相應寬幅安全區。

標出玩家／敵人活動區、血條／意圖、頂部 HUD、底部手牌與 modal 文字區。Player、EnemyContainer、Hand 的根 rect 只是容器起點，不是動畫的外接矩形；安全區須納入動畫伸展、手牌 hover 與目標提示，由 combatants／animation／UI owners 提供最大範圍，不照靜止姿勢挖窄洞。背景焦點、地平線、光源與前景遮擋配合角色版本；身體周圍保留可辨識亮度，UI 字區避免高頻細節。主選單按標題與按鈕實際範圍另行避讓。

### 決定單張或多層交付

既有外部背景路徑只載一張 Texture2D。單張可完成就合成輸出並保留分層母稿與合成參數；前景遮擋、動態雲霧或視差的分層是設計交付選擇，不是框架已有的多層 API。先指定每層的 scene owner、z／順序與是否隨鏡頭動，交 UI／VFX 實作後才標已整合；逐層輸出不以檔名順序代替正式合成順序。

透明前景按 scene 座標交同尺寸畫布或明確 offset，切片交 rect／拼接邊界，平鋪圖交重複方向與接縫規格，避免前景遮住手牌。背景按鈕仍處理左右鍵；新增裝飾層要由 UI 保留輸入穿透。

區域材質、色調、光源與構圖語彙沿 [style-guide](style-guide.md)；日夜／事件變體只在需求存在時製作。背景與角色共同調色時提高風格版本並通知相關素材重驗。

### 專項驗收

針對 Act-only、Location override、Event override、全空與連續跨節點切換建立 loader／texture 斷言。主選單及新增前景另驗實際 scene 節點和繪圖／輸入順序，不以戰鬥背景測試代替；多層需求驗離場與重入後沒有重複層或殘留。視覺層需在玩家／最大敵人、滿手牌、意圖提示、長文 modal 等情境檢查對比、裁切與遮擋；rect 斷言只能證明配置。

## 交接

交 UI 每層來源畫布、offset、合成順序、拉伸／裁切、輸入責任與安全區；交關卡 owner Act／Location／Event ID 與覆寫範圍；交人物與 VFX owners 光源、活動區與遮擋約束。未實作的多層／視差／動態背景是具體下一步，不當成素材缺檔。
