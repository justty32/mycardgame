# 玩家、敵人與頭目的外觀套件

[美術入口](../art-assets.md)｜[共同製作](static-assets.md)｜[角色來源](../../../../analysis/slay-the-robot/design/art-production.md#戰鬥人物與頭目共用的容器)

**何時用**：製作玩家、一般敵人、精英／頭目的立繪、選角頭像、圖鑑圖與動畫母稿，或批次換外觀。**何時不用**：敵人意圖與數值走 [enemy-design](../enemy-design.md)，逐格及時間線走 [animation](animation.md)，純血條／目標介面走 [UI](../ui.md)。

欄位、容器尺寸與 sprite 原點見頁首來源及其前一節「角色圖」；共同製作規則依 [static-assets](static-assets.md)。

## Done when

套件檔及角色身分／視覺規格存在，紀錄包含每個用途的輸出、原點／朝向／畫布、母稿版本及使用 ID。已接入的頭像／圖鑑／SpriteFrames 各有對應檢查結果；新立繪消費端、頭目擴大場景或動畫尚未完成者逐項列明。不可用一張圖載入證據宣稱整個角色外觀完成。

## 流程

### 先決定同一角色出現在哪裡

用穩定 object_id 聯繫外觀，不以檔名當資料註冊。頭像（character_icon_texture_path）、圖鑑（enemy_texture_path）與戰鬥身體（character_animation_id／enemy_animation_id）是不同入口；宣傳立繪可作母稿，但要分別產各用途的裁切，不能一張圖取代全部。

選角頁大型立繪與頭目專屬畫布、血條或滿版背景目前都沒有消費端（頭目仍用一般 Enemy 場景）；需求包含時先讓 UI／關卡 owner 定義實際容器與文字避讓，沒有接點不宣稱填值即可。

### 先固定身份與輪廓，再切用途

依 [style-guide](style-guide.md) 固定身體比例、標誌性形狀、材質／光源與主色語意；同陣營可有家族共通規則，但頭目變大不是唯一辨識方式。以當次實際需求選代表，不擅自新增角色。記左右朝向與是否容許鏡像，服飾、武器與文字不可在鏡像後失去身份含義。

頭像以選角按鈕的 64×64 最小區域決定裁切；圖鑑尺寸從 CodexEnemiesMenu 實際 TextureRect 取得，不假設與戰鬥畫布相同。戰鬥根的 200×144 是容器不是強制素材尺寸；依 sprite position、血條／名稱／SelectionButton 子節點設腳底或重心基準，再決定透明邊界。變大畫布不會自動擴大命中區。

輸出至少保留任務需要的母稿、用途裁切及動畫用中性姿勢；逐格、分層部件或 sheet 只有需求需要才製作。交動畫母稿時寫骨架關節／部件重疊、遮擋順序、握持點、腳底基線與可動範圍；採切片則交每格 rect／順序、同尺寸畫布與原點，不能只交一張大 sheet。

### 變體與替換

敵人圖鑑靜態外觀與戰鬥 idle 指向同一身份版本；頭像可以重新構圖，但共用標誌特徵。受擊、攻擊、死亡是動畫狀態，不用改 enemy_texture_path 達成。頭目階段變身先查有無換 AnimationData 的行為接點；無接點就交機制 owner，素材僅標待接線，不發明自動 phase 欄位。

hash 鏈涵蓋母稿→各裁切→frames。只改頭像時重驗該用途；輪廓、畫布或光源改版則通知動畫與 VFX owner 重查原點、碰撞視覺及命中位置。資料與 AnimationData 註冊沿 [content](../content.md)。

### 專項驗收

背景接線層分別驗 CharacterSelectionButton.texture_normal、CodexEnemiesMenu texture、Player／Enemy 的實際 SpriteFrames；動畫狀態／播放／釋放由 animation 流程驗，不能由母稿檢查代替。頭目與大型敵人放到該事件的 HBoxContainer 或定位 slots 驗相鄰敵人、血條、意圖、傷害數字與玩家目標區的幾何與父子關係，覆蓋正常、目標預覽、多狀態圖示與死亡／退出後；rect 證據不能宣稱畫面無遮擋。

## 交接

交動畫 owner 母稿、可動部位、朝向／原點／基線、狀態需求及版本；交 VFX owner 命中位置與允許遮擋範圍；交 UI owner 頭像／圖鑑裁切、安全區及大型外觀對容器的需求。交付紀錄同時列「素材已產出」「使用端已接線」「動畫已驗」「視覺待驗」，不合併成模糊的角色完成。
