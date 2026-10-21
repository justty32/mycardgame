# 玩家、敵人與頭目的外觀套件

[美術入口](../art-assets.md)｜[共同製作](static-assets.md)｜[角色來源](../../../../analysis/slay-the-robot/design/art-production.md#戰鬥人物與頭目共用的容器)

**何時用**：製作玩家、一般敵人、精英／頭目的立繪、選角頭像、圖鑑圖與動畫母稿，或批次換外觀。**何時不用**：敵人意圖與數值走 [enemy-design](../enemy-design.md)，逐格及時間線走 [animation](animation.md)，純血條／目標介面走 [UI](../ui.md)。

## Done when

套件檔及角色身分／視覺規格存在，紀錄包含每個用途的輸出、原點／朝向／畫布、母稿版本及使用 ID。已接入的頭像／圖鑑／SpriteFrames 各有對應檢查結果；新立繪消費端、頭目擴大場景或動畫尚未完成者逐項列明。不可用一張圖載入證據宣稱整個角色外觀完成。

## 流程

### 先決定同一角色出現在哪裡

讀來源與 [CharacterData](../../../../game/data/readonly/CharacterData.gd)、[EnemyData](../../../../game/data/prototype/EnemyData.gd)，用穩定 object_id 聯繫外觀，不以檔名當資料註冊。玩家頭像用 character_icon_texture_path；戰鬥身體用 character_animation_id。敵人圖鑑用 enemy_texture_path，戰鬥用 enemy_animation_id。獨立宣傳立繪可作母稿，但要分別產頭像、圖鑑與戰鬥用途的裁切，不能直接一張圖取代全部。

選角頁 character_background_texture_path 沒有已找到顯示端，若需求包含大型立繪就交 UI 新建層與文字避讓；沒有接點不宣稱填值即可。BOSS／MINIBOSS 是 EnemyData 的類型，已讀 EnemyContainer 仍用 Scenes.ENEMY 建立；頭目不會自動取得較大畫布、特殊血條或滿版背景。需要這些效果時先讓 UI／關卡 owner 定義實際容器。

### 先固定身份與輪廓，再切用途

依 [style-guide](style-guide.md) 固定身體比例、標誌性形狀、材質／光源與主色語意；同陣營、不同職責可有家族共通規則，但頭目變大不是唯一辨識方式。以當次實際玩家／敵人／頭目需求選代表，不擅自新增角色。記左右朝向與是否容許鏡像，服飾、武器與文字不可在鏡像後失去身份含義。

頭像以 CharacterSelectionButton 的 64×64 最小區域決定裁切；圖鑑尺寸從 Root 的 CodexEnemiesMenu 實際 TextureRect 取得，不假設與戰鬥畫布相同。戰鬥的 Player／Enemy 根最小區域皆 200×144，但 sprite 原點不同，這是容器不是強制素材尺寸。依來源的 position、血條／名稱／SelectionButton 子節點設角色腳底或重心基準，再決定透明邊界。變大畫布不會自動擴大命中區。

輸出至少保留任務需要的母稿、用途裁切及動畫用中性姿勢；逐格、分層部件或 sheet 只有需求需要才製作。若交動畫母稿，寫骨架關節／部件重疊、遮擋順序、握持點、腳底基線與可動範圍。現成 AnimationData 不自動切 sheet；若採切片，交每格 rect／順序、同尺寸畫布與原點，交動畫 owner 實作並驗實際 frame，不能只交一張大 sheet。

### 變體、替換與整合

敵人圖鑑靜態外觀與戰鬥 idle 必須指向同一身份版本；頭像可以重新構圖，但共用標誌特徵。受擊、攻擊、死亡是動畫狀態，不用改 enemy_texture_path 達成。頭目階段變身若需求存在，先查有無階段換 AnimationData 的行為接點；無接點就交機制 owner，素材狀態僅標待接線，不能發明自動 phase 欄位。

沿 static-assets 保留來源／權利、母稿→各裁切→frames 的 hash 與風格版本，正式檔用穩定用途名。只有頭像改版時重驗該用途；輪廓、畫布或光源改版則通知動畫與 VFX owner 重查原點、碰撞視覺及命中位置。資料、圖像與 AnimationData 註冊沿 [content](../content.md)，不重用仍持有舊 cache 的程序驗替換。

### 專項驗收

檔案層完整解碼並核對透明邊與非空主體規格；背景接線層分別驗 CharacterSelectionButton.texture_normal、CodexEnemiesMenu texture、Player／Enemy 的實際 SpriteFrames。目標 loader 不可 fallback；動畫狀態／播放／釋放由 animation 流程驗，不能由母稿檢查代替。

頭目與大型敵人須放到該事件的自動 HBoxContainer 或定位 slots 專項驗；查相鄰敵人、血條、意圖、傷害數字與玩家目標區是否重疊。可用 rect／節點資料檢查幾何與父子關係，不能據此宣稱畫面無遮擋。至少覆蓋正常、目標預覽、多狀態圖示與退出／死亡後的場景狀態；視覺、真實命中與動畫一致性需要 GUI，未執行時保留待驗。

## 交接

交動畫 owner 母稿、可動部位、朝向／原點／基線、狀態需求及版本；交 VFX owner 命中位置與允許遮擋範圍；交 UI owner 頭像／圖鑑裁切、安全區及大型外觀對容器的需求。交付紀錄同時列「素材已產出」「使用端已接線」「動畫已驗」「視覺待驗」，不合併成模糊的角色完成。
