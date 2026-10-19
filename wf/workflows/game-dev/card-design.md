# card-design — 把卡牌構想接入可取得、可驗證的內容

[遊戲開發](README.md)｜[內容接線](content.md)｜[卡牌評量](card-evaluation.md)｜[核實筆記](../../../analysis/slay-the-robot/design/cards.md)

**何時用**：設計新卡、卡組原型、升級或稀有度變體，並準備由 agent 寫成框架內容。

**何時不用**：只想評估既有卡走 card-evaluation；現有原語無法表達效果走 [mechanics](mechanics.md)；美術與文字排版接 [ui](ui.md)。本流程不替使用者決定尚未指定的題材或整套遊戲核心。

## Done when

任務內存在已填設計 brief、具來源的卡牌資料與取得接線，以及基礎／升級／拒絕路徑的驗證報告。資料實作任務須有隔離載入與指定入口測試回傳預期結果；純設計任務則有未實作標記與下一個實作入口。報告逐項標明已驗、未驗及取捨；文件 strict lint 回傳 0。

## 流程

### 先固定意圖與證據

先讀本任務適用的 wf 規矩與 [使用者邊界](../common/user.md)。2026-10-19 核對基準是上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 與本地修復；核實筆記列出實際來源。換版本或更動 schema 後重新追呼叫鏈，不以分析取代程式。

將設計 brief 填在任務產物，內容欄位已抽到 [card-design-fields.json](card-design-fields.json)（9 列）。`id` 為欄位代號，`record` 是必填內容，`check` 是完成檢查，`basis` 區分設計要求與框架契約。它是填寫規格，不是已完成設計；長卡表依 [資料契約](../common/data-files.md) 存資料檔。

先用一句話說玩家為何選這張卡、要在什麼情況作出什麼選擇，再定角色：立即輸出、防禦、循環、成長、鋪墊或回報。角色是設計標籤，不等於框架 `card_type`。比較同階段、同取得成本的替代卡與跳過獎勵；指出它必須付出的費用、抽牌機會、回合或構築成本，以及不擅長的情境。別先把數值填滿再找理由。

### 用實際 schema 寫最小版本

先讀 [CardData](../../../game/data/prototype/CardData.gd) 與相近的 [產生器實例](../../../game/autoload/GlobalTestDataGenerator.gd)。新內容優先獨立 mod；JSON 使用 `patch_data`／`properties` 外殼，`properties.object_id` 是穩定 ID。僅寫當前宣告且需要的欄位，保留預設值的理由；官方 example_mod 含過時欄位，不能當完整 schema 複製。

下列是**新卡檔的最小形狀示意**，數值只用於驗證接線，未寫入遊戲、未評為平衡；`card_type=0` 為 ATTACK，`card_rarity=1` 為 COMMON，須隨 enum 重新核對。

```json
{
  "patch_data": {},
  "properties": {
    "object_id": "card_project_example",
    "card_name": "示意卡",
    "card_description": "造成 [damage] 傷害。",
    "card_color_id": "color_red",
    "card_energy_cost": 1,
    "card_type": 0,
    "card_rarity": 1,
    "card_requires_target": true,
    "card_values": {"damage": 6, "number_of_attacks": 1},
    "card_play_actions": [{
      "res://scripts/actions/combatant_actions/ActionAttackGenerator.gd": {}
    }],
    "card_upgrade_value_improvements": {"damage": 3}
  }
}
```

將需要升級／加成的數值放 `card_values`，action 只放確實要蓋過它的參數。[BaseAction.get_action_value](../../../game/scripts/actions/BaseAction.gd) 先讀 action 自己的值，再讀出牌 request 的快照；因此 action 寫死 `damage`／`draw_count`，會使同名 `card_values` 升級不生效。重複同類 action 但使用不同數值時用 `custom_key_names`，同時核對描述預覽映射。抽牌參數為 `draw_count`，攻擊用 AttackGenerator，不把建構成功當作效果成功。

多效果明寫自然語言執行順序，再沿 [ActionGenerator](../../../game/autoload/ActionGenerator.gd) 和 [HandManager](../../../game/autoload/HandManager.gd) 核實 stack 順序；預設陣列後項先執行。先抽再打、先上狀態再打、擊殺追加均須測可區分順序的狀態。需要新 action／validator 時先交 mechanics，不用描述文字假裝已有行為。

### 費用、循環與升級須一起設計

普通能量與 X 費不同；X 費由 `card_energy_cost_is_variable` 與 upper bound 控制，實付費用另受攔截及暫時費用覆蓋。測 0 能量、剛好足夠、不足、上限、複製及自動出牌；不直接寫 `card_energy_cost=-1` 表達 X。降低到 0 費時重新檢查抽牌與回收是否形成無限循環。

以出牌後／回合後去向、保留、虛無及抽牌觸發說明卡如何離開牌循環。追蹤抽、棄、消耗、生成、回手各自成本；一回合內淨能量不減且可重建手牌／牌堆的組合列為循環候選，須有行動／回合上限及可重現 trace。不能只比較面板傷害除以能量，0 費卡尤其需要抽牌槽位與時間成本。

`upgrade_card()` 首次先套 `card_first_upgrade_value_changes`、`card_first_upgrade_property_changes`，之後每次才加 `card_upgrade_value_improvements`。分別列基礎、首升、上限時的有效值與敘述。戰鬥牌是永久牌的副本，`parent_card` 指回原牌；永久升級、僅本戰升級不能混用。現有 UpgradeCards 的 count／bypass 對副本與 parent 傳遞不一致，需多次升級時按核實筆記先補專項測試。

### 接入卡包與取得入口

按 [content](content.md) 為 mod 登記 cards→`CardData`／`_id_to_card_data`，若新增卡包則登記 card_packs→`CardPackData`／`_id_to_card_pack_data`，在 mod_list 啟用並記錄優先順序。卡包、角色 patch 都用同一 JSON 外殼；同 ID 修改須明定每欄 patch 策略，普通 Dictionary 合併為淺合併，Array append 不可套給 Dictionary。

起始牌從 `CharacterData.character_starting_card_object_ids` 進新 run；獎勵候選則由 `character_starting_card_draft_card_pack_ids` 指向卡包，二者分開驗。卡包自動篩色、標準類型／稀有度、appears 及 validator，**最後才 include 明列 IDs**；明列 ID 能繞過前述篩選。玩家 draft whitelist 又在 blacklist 之後加入，衝突時不要猜黑名單優先。

完整重啟隔離副本重建 Global pack cache，以新 run 驗起手；查玩家 draft cache、稀有度 bucket，再走實際獎勵選牌加入 deck。稀有度權重、保底狀態、池內同稀有卡數共同影響出現率；改成 RARE 不是單純改標籤。空／耗盡 bucket 可能給不足張數，不能用「卡已註冊」代替取得驗證。改 ID 或永久牌欄位時接存讀相容驗證。

不要為每張卡另建 pack。當任務沿用 `character_red`，現有 `card_pack_red` 已篩 `color_red`；COMMON ATTACK 且 appears=true 的新卡可直接納入，仍須斷言 cache／bucket 與真實取得。只有需要獨立取得範圍才新增 pack。模組從零登記依 content，勿把官方 example_mod 全卡欄位當新 schema。

### 將驗收接進可跑的測試

2026-10-19 冷讀 [runner](../../../tools/test_game.py) 與 [fixture](../../../tests/combat_fixture.gd)：現有 Combat 會覆寫起始牌組，`combat_flow._play()` 的扣費斷言固定為 1；它不會因 mod 新增卡而自動測到該卡。安排專項載入／出牌／升級／取得 assertions，交 runner owner 接入隔離執行與完成標記。現在沒有 `--suite Cards` 或任意腳本參數，不得虛構命令；已有 Smoke／Combat 成功只作基準。此結論為靜態核對，非新卡執行證據。

## 交接

交 [card-evaluation](card-evaluation.md) 時附 brief、版本／mod 次序、實際 card／pack／character ID、基礎與升級期望、可到達情境、測試與未驗項。圖片、聲音、UI 文案仍需相應領域驗收；目前禁止視窗與桌面操作，背景資料證據不能當作視覺／可玩樂趣評價。更新領域分析與流程，導航由整合 agent 維護。
