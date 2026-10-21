# card-design — 把卡牌構想接入可取得、可驗證的內容

[遊戲開發](README.md)｜[內容接線](content.md)｜[卡牌評量](card-evaluation.md)｜[核實筆記](../../../analysis/slay-the-robot/design/cards.md)

**何時用**：設計新卡、卡組原型、升級或稀有度變體，並準備由 agent 寫成框架內容。

**何時不用**：只想評估既有卡，走 [card-evaluation](card-evaluation.md)；現有原語無法表達效果，走 [mechanics](mechanics.md)；美術與文字排版接 [ui](ui.md)。本流程不替使用者決定尚未指定的題材或整套遊戲核心。

## 最小可行範例

先找最接近的現成卡再改，不從空白檔開始。

- **一般攻擊卡**：形狀見下方「用實際 schema 寫最小版本」的 JSON（`ActionAttackGenerator`）。
- **推動敵人的卡**：效果原語是 `ActionDisplaceUnit`（`game/scripts/actions/board_actions/ActionDisplaceUnit.gd`，在 `card_play_actions` 以完整腳本路徑為 key），參數 `mode:"PUSH"`。推動格數與碰撞傷害放 `card_values` 的 `distance`、`collision_damage_per_cell`，選格範圍放 `card_values.board`（`range`、`shape`、`target_faction`）。現成範例是 [demo_push.json](../../../examples/board-lab/pack/cards/demo_push.json)；其餘 mode（PULL、PULL_ADJACENT、SWAP、TO_CELL）與參數說明在該腳本開頭註解。
- 盤面專屬效果在未掛棋盤時於扣費前被拒絕；這類卡一律依 [validation 的棋盤開關](validation.md#棋盤開關兩種模式都要驗) 同時跑 `--suite Boardless` 與 `--suite DualBoard`。棋盤卡的新選項與舊欄位相容見 [可選模組](mechanics/board-module.md)；普通卡維持原出牌路徑。

## Done when

`games/<game>/design/specs/` 內存在已填設計 brief、具來源的卡牌資料與取得接線，以及基礎／升級／拒絕路徑的驗證報告。資料實作任務須有隔離載入與指定入口測試回傳預期結果；純設計任務則有未實作標記與下一個實作入口。報告逐項標明已驗、未驗及取捨；文件 lint 通過（見 [testing](../testing.md#文件檢查修改後必跑)）。

## 流程

### 先固定意圖與證據

核對基準與重查時機見 [validation](validation.md#現有基準與命令)，核實筆記列出實際來源。

將設計 brief 填在該任務的 spec（`games/<game>/design/specs/`），內容欄位已抽到 [card-design-fields.json](card-design-fields.json)（9 列）。`id` 為欄位代號，`record` 是必填內容，`check` 是完成檢查，`basis` 區分設計要求與框架契約。它是填寫規格，不是已完成的設計；長卡表依 [資料契約](../common/data-files.md) 存資料檔。

先用一句話說玩家為何選這張卡、要在什麼情況作出什麼選擇，再定角色：立即輸出、防禦、循環、成長、鋪墊或回報。角色是設計標籤，不等於框架的 `card_type`。比較同階段、同取得成本的替代卡與跳過獎勵；指出它必須付出的費用、抽牌機會、回合或構築成本，以及不擅長的情境。不要先把數值填滿再找理由。

### 用實際 schema 寫最小版本

先讀 [CardData](../../../game/data/prototype/CardData.gd) 與相近的 [產生器實例](../../../game/autoload/GlobalTestDataGenerator.gd)。新內容優先放獨立 mod；JSON 使用 `patch_data`／`properties` 外殼，`properties.object_id` 是穩定 ID。只寫目前宣告且需要的欄位，保留預設值要有理由；官方 example_mod 含過時欄位，不能當完整 schema 複製。

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

需要升級或加成的數值放 `card_values`，action 只放確實要蓋過它的參數：[BaseAction.get_action_value](../../../game/scripts/actions/BaseAction.gd) 優先讀 action 自己的值（優先序見 [核實筆記](../../../analysis/slay-the-robot/design/cards.md#原型執行值與升級)），action 若寫死 `damage`／`draw_count`，同名 `card_values` 的升級就不會生效。重複同類 action 但使用不同數值時用 `custom_key_names`，同時核對描述預覽的映射。抽牌參數為 `draw_count`，攻擊用 AttackGenerator；不要把建構成功當作效果成功。

多效果要明寫自然語言的執行順序，再沿 [ActionGenerator](../../../game/autoload/ActionGenerator.gd) 和 [HandManager](../../../game/autoload/HandManager.gd) 核實 stack 順序（規則見 [mechanics 的順序與等待](mechanics.md#順序與等待)）。先抽再打、先上狀態再打、擊殺追加，都要用能區分順序的狀態來測。需要新 action／validator 時先交 mechanics，不用描述文字假裝已有行為。

### 費用、升級、取得與測試

- 費用、X 費、牌循環與升級的設計和驗證：[費用、循環與升級](card-design/cost-upgrade.md)。
- 接入卡包、起始牌組與獎勵取得，並把驗收接進可跑的測試：[取得入口與測試接線](card-design/acquisition.md)。

## 交接

交 [card-evaluation](card-evaluation.md) 時附 brief、版本／mod 次序、實際 card／pack／character ID、基礎與升級期望、可到達情境、測試與未驗項。圖片、聲音、UI 文案仍需相應領域驗收；headless 的資料證據不能當作視覺或可玩樂趣的評價。更新領域分析與流程，導航由整合 agent 維護。
