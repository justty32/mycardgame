# art-assets — 圖像、角色動畫與特效素材

[遊戲開發入口](README.md)｜[UI 接線](ui.md)｜[內容接線](content.md)｜[已核實呈現架構](../../../analysis/slay-the-robot/design/presentation.md)

把美術需求轉成有來源、尺寸與使用入口的素材包；遊戲中的資料、場景與互動交給對應工作流接線。

**何時用**：卡圖、角色／敵人外觀、圖示、背景、逐格動畫、VFX 的製作、替換或批次風格統一。

**何時不用**：只有數值／規則走 [mechanics](mechanics.md)；只有版面／文字／命中區走 [ui](ui.md)。音訊使用遊戲開發入口的聲音流程。沒有美術需求時，不因工具可用就生成素材。

## Done when

專案內存在本次 brief、最終素材及來源／版本紀錄；紀錄填滿目標 ID、資料欄位或 scene 節點、實際尺寸、透明規格、使用權、整合路徑與驗收狀態。實際解碼與引用檢查回傳預期結果；如有接入遊戲，對應背景驗證有日誌。視覺驗收紀錄須註明檢查方式與未驗項；目前只能檔案修改與背景檢查，未完成視覺檢視時交付狀態為「素材／接線完成，視覺待驗」，不能標成視覺驗收通過。

## 流程

### 先取得使用規格

先讀 [使用者邊界](../common/user.md)、目標資料與 scene。brief 留在本次設計資料旁，包含用途、內容 ID、風格參考、輪廓／光源／配色、實際顯示尺寸、來源畫布、裁切安全區、透明背景、朝向與輸出格式。未定題材或美術方向先交可比較方案，不擅自把框架占位圖當成新遊戲的美術方向。

先以實際檔案讀長寬與色彩／alpha，再核對 scene 的 TextureRect、Sprite、scale 與父容器；PNG 有 alpha 通道不等於背景已透明。現有卡圖樣本為 96×96，Card 的圖像框也是 96×96，整張牌為 144×184；人物、敵人、圖示的其他樣本尺寸見呈現分析。這些是目前基準，不是所有新資產必須沿用的尺寸。需要高解析來源時另留母稿，交付尺寸仍依使用畫面決定。

### 選擇製作方式並保留來源

照片／插畫／紋理等點陣需求，任務真正需要時讀當前可用的 imagegen skill，依其工具產出與編輯；保留生成 brief、工具／模型資訊（可取得者）、版本與來源。既有 SVG、程式畫出的圖示或 theme 優先維護原格式；手繪、委製或現成素材則保留來源檔、作者與授權文本。不要把本機 skill 絕對路徑寫成專案依賴。

保留工作母稿與遊戲輸出之對應、版本或 hash；採用第三方素材前確認適用用途與署名。spire-codex 的研究角色不等於其圖片可直接收入遊戲。沒有授權依據的候選只留研究記錄，不作成品素材。生成結果同樣要核對輸出與引用素材的條件，不能把「AI 生成」當成已完成權利判斷。

以同一組代表樣本先驗輪廓、線條密度、留白、色彩語意與縮小後可辨識性，再批次製作。卡名、費用與規則文字由 UI 疊加，避免烘進卡圖；狀態不能只靠顏色區分。當前禁止桌面／視窗／截圖與 GUI；只可在既有授權內檢查素材檔案，不能藉製作素材開啟編輯器或預覽視窗。

### 命名、載入與替換

新遊戲素材優先放獨立 mod 的 `sprites/` 下，檔名以穩定內容 ID 與用途命名，動畫 frame 用固定寬度序號。資料填完整專案相對路徑，例如 `external/mods/<mod_id>/sprites/cards/<card_id>.png`；這是待替換模板，框架不會自動以 JSON 所在目錄解析素材路徑。

[FileLoader.load_texture()](../../../game/autoload/FileLoader.gd) 對外部圖像使用 `Image.load_from_file()` 與完整路徑快取。不要把這類欄位改成任意 `res://` 路徑、只換 `.import` 設定就假設生效，或在既有程序中換檔後判定新圖已載入。驗證用新建的隔離背景程序；一般打包的 scene／theme 資源則依 Godot 的 `ext_resource`、UID 與 Import 路徑處理。

卡圖交 `CardData.card_texture_path`；角色選擇圖交 `character_icon_texture_path`。戰鬥人物／敵人外觀交 `character_animation_id`／`enemy_animation_id` 對應的 AnimationData，不能只換圖鑑用的 `enemy_texture_path`。背景先確認 Act、Location、Event 的覆寫優先序。新增資料接 [content](content.md)，改位置、大小或畫面層次接 [ui](ui.md)。

### 動畫與特效

逐格動畫交付同尺寸／原點的 frames、順序、fps、單格時長、循環與下一狀態。現有 [AnimationData](../../../game/data/readonly/AnimationData.gd) 由 `_animation_data` 產生 SpriteFrames，使用 `animation_texture_file_paths`、`animation_frame_durations`、`animation_fps`、`animation_next_animation_name`；不要把 sprite sheet 當成框架已支援的自動切圖格式。

人物至少核對 idle、attack、death；VFX 核對 `animation_default` 結束與釋放。death／一次性 VFX 不可循環，attack 應能回 idle。以實際載入後的 SpriteFrames 檢查 frame 數、fps、loop 與轉移，不只驗 JSON 存在；生成 helper 與重新載入的差異見呈現分析。效果時長、提示時機若牽涉出牌或傷害執行交 mechanics，不能用改動畫偷偷改戰鬥節奏。

### 驗收與交接

先核對每張圖可解碼、尺寸／alpha 規格、路徑大小寫、引用 ID、frame 缺漏與 placeholder fallback；背景匯入成功不足以證明外部檔案都被載入，需由目標 loader 與場景使用。按 [validation](validation.md) 選檢查，不為純換圖跑全套戰鬥。打包時另核對 `exported` feature 與 exe 旁的 external 檔案；尚未做成品測試就保留未驗。

允許視覺驗收時，在實際使用尺寸檢查裁切、透明邊、模糊、背景對比、遮住數值與動畫跳動；另驗授權支援的 viewport。現階段此項保留待驗，不呼叫 capture／UI 工具。視覺好看與檔案可載入是兩份證據。

## 交接

### 一張新卡的跨領域接線

先由 [內容 bootstrap](content/bootstrap.md) 固定 mod、card 與取得入口，再沿 `CardData.card_texture_path → FileLoader.load_texture → Card.update_card_display → CardTexture` 接圖。音效獨立接 `card_play_actions` 的 `Scripts.ACTION_PLAY_SOUND`，填完整專案相對 `audio_path`；成功出牌或命中時機須依 [audio](audio.md) 定義，並核對 action 陣列後項先執行。卡名、費用與描述仍由資料／UI 提供。

同一份交接記錄串起內容 ID、圖／音路徑、顯示框、播放事件及驗收。先驗資產解碼及 ID，再由 bootstrap 的 helper 接入既有 Smoke 驗目標 loader 非 fallback、Card 等待刷新後的 texture／文字；新卡音效的成功一次、拒絕與預覽零次須另加無聲專項。既有 Smoke 不會自動驗這條鏈，背景通過仍留下視覺／聽感待驗。

交 UI agent：最終路徑、尺寸／原點／安全區、狀態變體、動畫時序與未驗項。交內容 agent：內容 ID→資料欄位→素材路徑，並列需註冊的 AnimationData／mod。批次紀錄超過 1 KB 時依 [data-files](../common/data-files.md) 用 `wf-table/1`，透過 tabledb 讀寫；不在多篇 md 複製素材清單。同步本次分析、工作流與 [strict lint](../testing.md)，不把工具改造成 MCP 當作素材製作的前置條件。
