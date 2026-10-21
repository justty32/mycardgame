# 分階段計畫（§5）：Phase 4–6（未動工）

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 4：多主角資料模型 + AI 隊員戰鬥行動

可玩：主角 + 2 名 AI 隊員。

### 改動

`PartyMemberData.gd`（新）、`PlayerData` 改造 + proxy（§4.4）、`Global.start_run` 建隊伍、`CharacterData` 新欄位、`PartyUnit.tscn/gd`（由 `Player.tscn` 衍生，綁 member）、`Player.gd` 改為讀 member（傷害／格擋／血條／攔截器註冊：run modifiers 全員、遺物依 `artifact_trigger_scope`）、`HandManager.unit_piles` + proxy、`Hand` 綁行動單位、`AiProfileData.gd` + SCHEMA、`BaseUnitController`／`GreedyAiController`／`AiContext`／`AiPlan`、`CardData.card_ai_hints`、`BaseAction.get_action_value` 的 values 層改查行動單位 member_values、倒下流程（`unit_downed`、`downed_member_policy`）、`ActiveUnitPanel` UI、`StatsHandler` 的 players 群組統計改以 faction 判斷（`StatsHandler._on_combatant_block_broken`／`_on_combatant_blocked`／`_on_combatant_damaged` 的 `players` 群組判斷）。

### 規模與風險

規模：~1300 行；25 檔。

風險：高：proxy 期間雙真相；`register_artifact_interceptors` 掛錯單位會讓遺物對隊員失效或重複觸發；AI 用 preview 攔截估值時攔截器必須尊重 `preview_mode`（既有慣例，見 `BaseAction._intercept_action` 的 `preview_mode` 註解）。

### Done when

新 `tests/party_flow.gd`（suite `Party`）：fixture 隊伍 3 人（主角 PLAYER、兩名 AI 用框架測試 `ai_profile_test_aggressive`／`_defensive`），斷言各自牌堆獨立（主角出牌不影響隊員手牌）、各自能量、AI 隊員在自己的行動中發出 `ai_plan_decided` 且至少打出一張牌、攻擊型靠近敵人、防禦型對 HP<50% 主角出格擋、一名隊員倒下後主角仍可行動且戰後依 policy 回 1 HP；新 `tests/party_data_regression.gd`：主角 proxy 讀寫 == `player_party[0]`；`--suite All` 綠。

### agent

普通（opus）：資料模型/ proxy / AI 規劃器；普通（opus）：PartyUnit 與 UI；雜活：欄位、測試資料

## Phase 5：招募／培養／AI 選牌獎與購卡／升階

可玩：局中招募、戰後各自選牌。

### 改動

`ActionRecruitPartyMember`、`ActionDismissPartyMember`、`ActionSetActiveMembers`、`ActionAddCardToMemberDeck`、`ActionAdvanceMember`（+ `CharacterTierData`）；`Random.get_location_card_rewards` 每成員；`RewardOverlay`／`CardDraftSelectionOverlay` 顯示成員；`AiDraftScorer`、`AiShopper`；`ShopOverlay._on_continue_button_up` 觸發 AI 購買；`RestActionData.rest_action_targets_member` + `RestOverlay` 選成員；`PlayerData.add_card_to_deck` 系列搬 member；`ValidatorDeckHas*`（`validators/deck/`）改讀指定成員牌組。

### 規模與風險

規模：~900 行；18 檔。

風險：中：獎勵與商店流程有多個 overlay 與 `map_location_selected` 清理耦合（`RewardOverlay` 的 `_on_combat_started`～`_on_map_location_selected`）。

### Done when

新 `tests/recruit_flow.gd`（suite `Recruit`）：事件選項招募 → `party_member_recruited`、名冊 2 人、超過上限被拒；戰後兩組牌獎各加入正確牌組；AI 成員預算 30% 時商店購買一張且金錢扣對；升階動作加卡並改 `member_tier_id`；`--suite All` 綠。

### agent

普通（opus）；AiDraftScorer 雜活

## Phase 6：存檔版本拒絕與收尾

可玩：舊存檔被拒絕並提示；proxy 清除。

### 改動

`FileLoader.load_game` 接版本檢查與拒絕提示、`PlayerData.player_save_version`（不做遷移、不寫 `SaveMigration`；已決，decisions.json 第 14 列）；刪 `PlayerData`／`HandManager` proxy 並改完剩餘引用（rg `player_data.player_energy|player_health|player_block|player_deck|HandManager.player_hand`）；`Signals` 舊訊號加一次性 warning；code-map／analysis 架構文件／`game-dev/mechanics.md` 同步；`analysis/slay-the-robot/architecture/02_extension_points.md` 補新 SCHEMA 類別與訊號。

### 規模與風險

規模：~300 行 + 文件。

風險：低：舊格式 fixture 要用真實 v1 存檔（從現行 `save_load_flow.gd` write 階段產生並固化進 tests，只用來驗證被拒絕）；Phase 4–5 期間開發用存檔不保證相容。

### Done when

`save_load_flow.gd` 新階段 `reject_legacy`：載入 v1 fixture → 被拒絕並顯示提示、不改動目前狀態、進 rejected 清單；`invalid_version` 同樣進 rejected 清單；v2 存檔存讀正常；`rg` 證明 proxy 引用為 0；V1–V3、`--suite All`、所有新 suite 綠；code-map 更新。

### agent

普通（opus）；文件雜活
