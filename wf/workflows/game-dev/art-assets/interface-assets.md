# 介面圖像套件：對話、商店、獎勵、地圖與選單

[美術入口](../art-assets.md)｜[共同製作](static-assets.md)｜[UI 場景組合](../ui/screens/README.md)｜[介面來源](../../../../analysis/slay-the-robot/design/art-production.md#介面圖片與程式樣式的界線)

**何時用**：要為一個完整畫面交付一致的圖像／按鈕／面板素材包，而非單張 icon。**何時不用**：畫面流程、命中、焦點與事件接線由 UI 場景流程負責；卡面走 [cards](cards.md)，人物走 [combatants](combatants.md)，全景走 [environments](environments.md)。

節點、尺寸與現有消費端見頁首來源及各場景檔；共同製作規則依 [static-assets](static-assets.md)。

## Done when

任務畫面的套件規格與輸出檔存在，每件都有實際節點／欄位或明確待實作接點、尺寸來源、切片／拉伸區、狀態與版本；字與數字保留為 UI。整合需求有各狀態的資源、幾何及資料更新證據；未視覺／互動驗收的層次明列，不以一張整體設計圖當成已接線 UI。

## 流程

### 以畫面與狀態收集素材需求

先由場景檔固定玩家任務、狀態和版面，再逐層分出裝飾圖、資料圖、文字、互動容器和遮罩。套件只含這次畫面實際需要的面板／邊框、按鈕與圖示、主插畫、共用配色及狀態規格；實際圖片需求、程式樣式和待新建消費端分開標。

**對話**（[dialogue](../ui/screens/dialogue.md)）：以 456×456 狀態插圖區與標題／prompt／選項區為基準。沒有 speaker portrait 欄位；左右立繪、姓名牌或表情切換先由 UI owner 定義節點與資料映射，再製作用途分明的角色裁切。對話框可交延展面板與選項 normal／hover／不可用規格，不把 prompt 烘進背景；空圖路徑的現行行為見場景檔，交接需明示清空策略。

**商店與休息**（[shop-rest](../ui/screens/shop-rest.md)、[rest-services](../ui/screens/rest-services.md)）：商品卡沿用 Card 視覺，遺物／消耗品按鈕讀 artifact_texture_path／consumable_texture_path 填到 Button.icon。交付商品圖示、容器皮膚及離開按鈕所需狀態；價格、缺錢提示與已購項目由 UI／資料控制。休息選項沒有 icon 消費端，新 icon 包需 UI 映射，不能改 rest action 規則來讓圖片出現。

**獎勵**（[rewards-selection](../ui/screens/rewards-selection.md)）：區分 RewardOverlay 的「領取某種獎勵」按鈕與後續選牌畫面的實際 Card。ArtifactRewardButton 載遺物圖，MoneyRewardButton／CardRewardButton 主要改文字；新錢幣或卡包圖示需明列動態映射接線，不能把獎勵按鈕當成已顯示的卡圖。被領取／可跳過／選牌取消等狀態由 UI 流程定義，圖片包只按其契約交付。

**地圖**（[map](../ui/screens/map.md)）：以 64×64 節點按鈕與下方標籤為基準；現況沒有依類型選 icon 的映射。戰鬥／商店／休息／寶箱／頭目圖示及已訪問／未知變體交 UI 定義映射與顯示優先序，未知節點不可因底圖洩漏類型。路線裝飾或連線先查實際生成端，不假造線段材質欄位。

**選單**（[menus-collection](../ui/screens/menus-collection.md)）：既有標題、面板與按鈕以文字及 StyleBoxFlat theme 呈現，沒有圖片 skin consumer；圖像 Logo、雕花按鈕或面板需給新增 TextureRect／StyleBoxTexture 的接點及伸縮規格，另含選角頭像、設定勾選／slider 與圖鑑圖像。主背景交 environments；文案、語系與字型交 UI，不能因換 skin 改 navigation NodePath。

### 製作與切片契約

共用邊角、面板、按鈕與 icon 沿 [style-guide](style-guide.md) 統一；先製作一個有長字的面板與一組最小 icon，確認規格後擴批。尺寸從 scene 的 offsets／minimum size／容器分配取得，來源畫布和實際顯示框分列。Button 的 normal／hover／pressed／disabled／focus 只交任務需要的狀態；由 theme 產生的狀態可交 theme 參數，不強制另畫 PNG。

延展面板標角邊與中心的 slice rect、content margins、可平鋪／拉伸範圍，由 UI owner 選 NinePatchRect 或 StyleBoxTexture；StyleBoxFlat 不讀切片。圖集交 atlas 索引與單件 rect、padding 及用途映射，不能只交 sheet。外部資料圖片與內建 theme 資源分開輸出。

### 組裝與專項驗收

交 UI 的是可替換零件與尺寸／狀態契約，不是把完整 mockup 當滿版圖片。裝飾層不得遮住輸入容器，mouse_filter、clip、層級、命中及焦點由 UI owner 定義；保留字區、價格、計數、選項長文與 tooltip 的安全區，圖示語意不只靠顏色。

依 [UI 專項驗證](../ui/verification.md) 驗實際 scene 節點取得正確資源，長文字容器與輸入層不被裝飾取代。情境：對話兩個有圖狀態及空圖切換；商店不同商品與缺錢／購入後；獎勵領取／取消；地圖已知／未知及可走／不可走；選單選取、停用與返回後重入。現有 suite 不涵蓋，需接實際 helper；設計稿存在不替代互動結果。

## 交接

UI owner 接完整畫面套件、切片、狀態映射、文字安全區、裝飾與輸入層責任；內容 owner 接資料型圖片 ID／路徑；缺少的消費端列具體檔案與下一步。改共用 skin 需通知全部使用畫面重驗。
