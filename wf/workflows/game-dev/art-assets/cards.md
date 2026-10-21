# 卡牌視覺套件：卡框、卡圖與狀態

[美術入口](../art-assets.md)｜[共同製作與驗收](static-assets.md)｜[卡牌來源](../../../../analysis/slay-the-robot/design/art-production.md#卡框裝飾與未實作卡背)

**何時用**：交付一套可進手牌、商店、圖鑑及選牌畫面的卡牌視覺，或替換卡框／卡圖／費用與裝飾。**何時不用**：只改卡牌效果走 [card-design](../card-design.md)；卡背翻轉與新視覺狀態若需邏輯，先由 [UI 互動](../ui/interaction-states.md) 定義消費端。

Card 節點與現況見頁首來源及 [Card 版面](../ui/components-layout.md)；共同製作規則依 [static-assets](static-assets.md)。

## Done when

任務套件紀錄及實際輸出存在，逐件填入 Card 或相關 scene 節點／資料欄位、尺寸來源、狀態、切片與版本；未實作項標「待接線」而非成品。接入需求有 Card 顯示刷新及各使用畫面的斷言證據；視覺、命中或翻面未驗者明列。

## 流程

### 先拆可交付的層

從實際需求選本套件包含哪些層，不把整張含字的平面圖當作可用卡牌：卡框目前是兩個 ColorRect，CardTexture 接 card_texture_path，費用圖接 ColorData，名稱、稀有度／類型、費用與描述是文字。花紋卡框交透明框圖或可延展邊框及切片規格，由 UI owner 新增 TextureRect／StyleBoxTexture 消費端，不能把框圖填到卡圖欄。

卡背與稀有度框圖目前沒有消費端。需要背面時先定義何時隱藏正面、翻面前後可見資訊及共用事件，再交 UI 實作；不能以 DrawPile 按鈕圖片冒充單卡背面。提出稀有度紋章或邊框變體時，一起列映射與未接線責任。

### 卡牌家族與尺寸契約

以一張實際卡為代表，沿 [風格流程](style-guide.md) 固定家族風格；卡圖可變主體，框線、費用徽記、字區與裝飾位置共用。卡名壓在圖框上緣、描述在下方、費用圖跨左上角；安全區對照各節點 offsets，不只留固定百分比。裝飾圖不能塞滿中央計數區。

卡框母稿標出外界、圖像窗、文字窗及透明洞；需切片時給 slice rect、邊界與可延展區，不切斷裝飾角。現有 ColorRect 沒有九宮切片契約，UI 決定採獨立 PNG 或 StyleBoxTexture 後才產出對應切片。費用／裝飾圖可從同風格母稿派生，不把帶數字的截圖作 UI 素材；能量圖同時用於 32×32 費用框與 16 像素寬描述圖，須留數字覆層並確認縮小後形狀可辨。

### 裝飾與互動狀態分開接

CardDecorator 含行為腳本與效果契約，不能為了外觀任意新增有遊戲效果的 decorator；純框邊效果由 UI 層實作，已有 decorator 換圖則保留其行為及數字。CardGlow、hover 與費用不足的真實用途見 [UI 互動](../ui/interaction-states.md)，不是每種狀態都有圖檔。先決定沿用程式效果還是新增圖片變體，記 normal／hover／選取／不可用的對應與優先序；不可把可出牌、被選中及稀有度畫成同一發光語意。

### 接入與專項驗收

用 [UI 驗證](../ui/verification.md) 接實際 helper。目標卡經 update_card_display 並等待 process_frame 後，核對 card_texture、文字、費用 texture／可見性、ColorBackground、decorator 數量與值；切換 validator、選牌與費用狀態時，分別核對 glow／文字的實際條件與解除後沒有殘留。新增框／背面／稀有度圖層各加 node 與映射斷言，不能只證明檔案已放入。

同套 Card 被手牌、商店與選牌重用。至少以最長實際文案、0／可變費用、多裝飾及使用中的稀有度測容器；商店價錢在牌底之外，不烘入卡面。牌尺寸改動交 Hand 寬度／曲線、CardButton 命中區及 shop 容器一併驗。文字／rect 斷言不能證明遮擋與可讀性。

## 交接

交 UI 卡牌分層順序、每層原點／透明窗、切片、狀態映射、文字保留區與未接線項；交內容卡 ID→圖路徑、ColorData 及既有 decorator ID。卡背或稀有度變體未有消費端時保持候選。卡牌移動／翻面／狀態轉場交 [UI 動態](motion/cards.md)，不以製圖改出牌規則。
