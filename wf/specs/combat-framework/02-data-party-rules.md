# 資料模型一：隊伍與戰鬥規則

[README](README.md)

## 3.1 資料模型（全部 `SerializableData` 衍生，`@export` 才存檔；新類別登記 `Global.SCHEMA`，並跑一次 `FileLoader._generate_base_mod_data()`）

### 3.1.1 隊伍

```
PlayerData（整局容器，沿用）
  + player_save_version: int = 2
  + player_party: Array[PartyMemberData]        # 名冊；[0] 固定為主角
  + player_active_member_uids: Array[String]    # 出戰者；空 = 全部
  + player_party_size_max: int                  # 名冊上限（來自 CombatRulesData 預設，可被事件改）
  + player_deploy_size_max: int                 # 出戰上限
  + player_party_budget_ratio: float            # AI 隊員購物預算比例（0 = 不買）
  共用保留：money、artifacts、consumables、map/location、rng、event pools、run stats、run modifiers、shop
  移除 @export（改為對主角／行動單位的 proxy，§3.3）：player_health、player_health_max、player_energy、player_energy_max、player_block、player_deck、reward_draft_card_pack_ids 與其快取

PartyMemberData extends PrototypeData（新；SCHEMA 不登記為讀取資料夾，只登記類別以便序列化）
  member_uid: String                 # 局內唯一（object_uid）
  member_character_object_id: String # 指向 CharacterData（讀取名稱、動畫、顏色、升階表）
  member_control_mode: int           # CONTROL_MODES {PLAYER, AI}
  member_ai_profile_object_id: String
  member_health / member_health_max: int
  member_energy_max: int             # 戰中 member_energy 不存
  member_speed: int
  member_move_range: int
  member_footprint: Vector2i = (1,1)
  member_deck: Array[CardData]
  member_reward_card_pack_ids: Array[String]（+ 不存檔的 filter/rarity cache，搬自 PlayerData.gd:122-124）
  member_tier_id: String             # 目前階位（CharacterTierData.object_id）
  member_values: Dictionary          # 取代 player_values 的角色層
  member_is_downed: bool             # 倒下；戰後依 CombatRulesData.downed_member_policy 處理
  member_status_snapshot: Dictionary # 預留；本版不用
```

`CharacterData` 新增：`character_speed`、`character_move_range`、`character_footprint`、`character_default_ai_profile_id`、`character_default_control_mode`、`character_recruit_validators: Array[Dictionary]`、`character_tiers: Array[CharacterTierData]`（embedded：`tier_object_id`、`tier_next_tier_ids`（分支）、`tier_requirement_validators`、`tier_on_advance_actions`（加／移卡、改屬性都用既有 Action）、`tier_ai_branch_weights`）。`character_starting_*` 欄位沿用為隊員初始化來源。

### 3.1.2 戰鬥規則（單一物件，內容包 patch）

```
CombatRulesData extends SerializableData（SCHEMA: "combat_rules/"；框架在測試資料註冊 object_id "combat_rules_default"）
  timeline_delay_scale: int = 100        # wait = action_delay * scale / speed
  default_action_delay: int = 100
  wait_action_delay: int = 50            # 空等
  extra_move_delay_per_cell: int = 0
  energy_per_action: int = -1            # -1 = 補滿到上限（框架預設 = 現行行為）；>=0 = 每次行動 +N
  energy_cap: int = -1                   # -1 = 上限即 member_energy_max
  draw_per_action: int = 5
  hand_limit: int = 10
  discard_hand_on_action_end: bool = true
  reset_block_on_action_start: bool = true
  free_move_per_action: int = 0
  distance_metric: int = MANHATTAN
  board_min_size: Vector2i = (5,5)
  default_board_size: Vector2i = (5,5)
  party_size_max: int = 1
  deploy_size_max: int = 1
  downed_member_policy: int = {REVIVE_AFTER_COMBAT_1HP, LEAVE_PARTY, PERMADEATH}
  hero_down_ends_run: bool = true
  tie_break: int = {HIGHER_SPEED_FIRST, PARTY_FIRST, SPAWN_ORDER}
```
