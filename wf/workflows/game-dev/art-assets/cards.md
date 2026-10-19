# 卡牌視覺套件：卡框、卡圖與狀態

[素材子流程](README.md)｜[共同製作與驗收](static-assets.md)｜[卡牌來源](../../../../analysis/slay-the-robot/design/art-production.md#卡框裝飾與未實作卡背)

**何時用**：交付一套可進手牌、商店、圖鑑及選牌畫面的卡牌視覺，或替換卡框／卡圖／費用與裝飾。**何時不用**：只改卡牌效果走 [card-design](../card-design.md)；卡背翻轉與新視覺狀態若需邏輯，先由 [UI 互動](../ui/interaction-states.md) 定義消費端。

## Done when

任務套件紀錄及實際輸出存在，逐件填入 Card 或相關 scene 節點／資料欄位、尺寸來源、狀態、切片與版本；未實作項標「待接線」而非成品。檔案檢查有結果，接入需求有 Card 顯示刷新及各使用畫面的斷言證據；視覺、命中或翻面未驗者明列。

## 流程

### 先拆可交付的層

先讀來源分析與 [Card.tscn](../../../../game/scenes/ui/card/Card.tscn)、[Card.gd](../../../../game/scripts/ui/card/Card.gd)，從實際需求選本套件包含哪些層，不把整張含字的平面圖當作可用卡牌。現成卡框由 ColorBackground／Background 兩個 ColorRect 組成；CardTexture 接 card_texture_path；費用圖接 ColorData；名稱、稀有度／類型、費用與描述是文字。需求若要花紋卡框，交透明框圖或可延展邊框及切片規格，另由 UI owner 新增 TextureRect／StyleBoxTexture 消費端，不能把框圖填到卡圖欄。

卡背在目前查核的 Card／Hand 與資料搜尋沒有找到獨立消費端。需要背面時可製作獨立背圖，但先定義何時隱藏正面、翻面前後可見資訊及共用事件，再交 UI 實作；不能以 DrawPile 按鈕圖片冒充單卡背面。稀有度目前是 CardType 的文字，沒有已核實的稀有度框圖路徑；提出紋章或邊框變體時須一起列映射與未接線責任。

### 建立卡牌家族與尺寸契約

以一張實際卡為代表，沿 [風格流程](style-guide.md) 固定家族風格；卡圖可變主體，框線、費用徽記、字區與裝飾位置共用。圖框 96×96、完整牌 144×184 是 scene 基準；卡名位於圖框上緣，描述在下方，費用圖跨左上角。安全區要對照各節點 offsets，不只留固定百分比。CardDecorator 圖示最小 24×24，中央另有數字；裝飾不能塞滿計數區。

卡框母稿要標出外界、圖像窗、文字窗及透明洞；需切片時給 slice rect、邊界與可延展區，不切斷裝飾角。現有 ColorRect 沒有自動九宮切片契約，UI 決定採獨立 PNG 或 StyleBoxTexture 後才產出對應切片。各費用／裝飾圖可從同風格母稿派生，但沿共同流程記母稿→輸出與 hash，不把帶數字的截圖作 UI 素材。

### 裝飾與互動狀態分開接

CardDecoratorData.card_decorator_texture_path 由 [CardDecorator](../../../../game/scripts/ui/card/CardDecorator.gd) 載入；非空才可見，card_decorator_label_value_name 指向數值欄。它含行為腳本與效果契約，不能為了外觀任意新增有遊戲效果的 decorator。純框邊效果可直接由 UI 層實作，已有 decorator 換圖則保留其行為及數字。

CardGlow 是 validator／選牌標記，不能直接當作可出牌狀態；hover 是 Card 的位移動畫與 Hand 排列，費用不足改文字顏色。先沿 UI 互動流程核對各標記的真實用途，不是每種狀態都有圖檔。先決定沿用程式效果還是新增圖片變體，記 normal／hover／選取／不可用的對應與優先序。不可把可出牌、被選中及稀有度都畫成同一發光語意。能量圖會共用在 32×32 卡費用框與 16 像素寬描述圖，須同時留數字覆層與縮小後形狀辨識。

### 接入與專項驗收

先完成共同 static-assets 的來源、解碼、版本及 loader 驗證，再用 [UI 驗證](../ui/verification.md) 接實際 helper。目標卡經 update_card_display 的等待後，要核對 card_texture、文字、費用 texture／可見性、ColorBackground、decorator 數量與值；切換 validator、選牌與費用狀態時，分別核對 glow／文字的實際條件與解除後沒有殘留。新增框／背面／稀有度圖層則各加 node 與映射斷言，不能只證明檔案已放入。

同套 Card 被手牌、商店與選牌重用。至少以最長實際文案、0／可變費用、多裝飾及使用中的稀有度測容器；CardShopButton 的價錢位於牌底之外，不把價錢烘入卡面。牌尺寸改動交 Hand 寬度／曲線、CardButton 命中區及 shop 容器一併驗。當前禁止 GUI／桌面／截圖與 Godot 的文件任務，只保存待跑檢查；文字／rect 斷言也不能證明遮擋與可讀性。

## 交接

交 UI 卡牌分層順序、每層原點／透明窗、切片、狀態映射、文字保留區與未接線項；交內容卡 ID→圖路徑、ColorData 及既有 decorator ID。母稿與正式輸出使用同一批次／風格版本；卡背或稀有度變體未有消費端時保持候選，不能掛完成狀態。卡牌移動／翻面／狀態轉場交 [UI 動態](ui-motion.md)，不以製圖改出牌規則；需要角色動作時才另接角色動畫。
