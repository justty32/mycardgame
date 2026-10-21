# 每單位牌堆（§3.3）

[README](README.md)｜[戰鬥迴圈與訊號](04-combat-loop-signals.md)

## 3.3 `HandManager` 的每單位牌堆

```
class UnitPiles（RefCounted）: hand, draw, discard, exhaust: Array[CardData]; custom_piles; cards_retained_this_action; cards_with_modified_action_energy
HandManager
  unit_piles: Dictionary[String, UnitPiles]      # key = unit_uid
  active_unit_uid: String
  func set_active_unit(unit) / get_piles(unit_uid) / get_active_piles()
  func generate_combat_deck(member: PartyMemberData)   # 從 member_deck 複製（取代現行 HandManager.generate_combat_deck()）
  var player_hand: Array[CardData]: get = _get_active_hand, set = _set_active_hand   # 相容 proxy（player_draw/discard/exhaust 同）
```
- 既有 14 個外部讀取者透過 proxy 不改即可編譯；但凡「指定單位」的新邏輯一律用 `get_piles(uid)`。`HandManager.STANDARD_PILE_NAME_TO_PILE_PROPERTY_NAME`的 `get/set` 路徑經 proxy 落到 active piles。
- `Hand`（UI）綁 `active_unit`：`Hand` 的 `player`（`@onready var player`） 改為 `HandManager.get_active_unit()`；`create_cards_in_hand` 在切換單位時整組重建。
- 能量：`Global.player_data.player_energy` 改為 proxy 到**行動中單位**的 `member_energy`（`CardData.get_card_energy_cost`、`Card.can_play_card`、`HandManager.add_card_to_play_queue` 不必改）；敵人沒有能量，AI 隊員有。
- `HandManager.perform_end_of_turn_hand_actions`改名 `perform_end_of_action_hand_actions(unit_uid)`，由 `CombatDirector._end_action` 依 `rules.discard_hand_on_action_end` 呼叫。
- `CardData.card_energy_cost_until_turn`語意改「直到持有者下次行動結束」，欄位名保留（JSON 相容）。

修訂（Phase 1）：`perform_end_of_action_hand_actions()` 已由 Director 依 `rules.discard_hand_on_action_end` 呼叫，舊名 `perform_end_of_turn_hand_actions` 保留為別名；尚無 `unit_uid` 參數，UnitPiles／proxy 留 Phase 4。另加 `get_hand_limit()` 讀 `rules.hand_limit`。

