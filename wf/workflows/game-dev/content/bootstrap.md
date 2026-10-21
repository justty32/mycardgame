# 第一個 mod：從檔案到隔離載入驗收

[內容入口](../content.md)｜[環境](../../dev-env.md)｜[驗證](../../testing.md)

**何時用**：fresh clone 後建立第一個獨立 mod，或要在候選副本試驗教學內容。**何時不用**：單純改既有卡數值回內容入口；新行為原語走 [mechanics](../mechanics.md)。本篇範例是 [新手指南](../../../../analysis/slay-the-robot/tutorial/beginner_guide_zh.md) 的重擊，不代表使用者已選定玩法。

## Done when

mod 三個資料檔與清單登記存在；專屬 helper 已接入既有 suite（見 [probe 與命令](bootstrap-probe.md)），其命令 exit 0、有本次斷言與完成標記、無禁止錯誤。這只完成載入驗收；卡牌出牌／預覽／存讀的任務須再取得對應證據。所有命令從本專案根開始。

## 準備候選副本

正式實作可直接修改授權中的 game／tests，再由 runner 隔離；若只是試教學、不應改原檔，先建唯一候選根。以下只複製 game、tools、tests，排除個人存檔、Git、cache 與連結，不複製引擎，也不刪來源。bash 用 heredoc；PowerShell 把同一段 Python 包成 `@' … '@ | python -`。

```bash
python3 - <<'EOF'
import shutil, uuid
from pathlib import Path
root = Path.cwd()
cand = root / 'artifacts' / f'mod-bootstrap-{uuid.uuid4().hex}'
base = shutil.ignore_patterns('.git', '.godot', '.import', '.saves', '.screenshots', 'profile.json', 'user_settings.json')
def skip(d, names):
    return set(base(d, names)) | ({'saves'} if Path(d).name == 'external' else set())
shutil.copytree(root / 'game', cand / 'game', symlinks=True, ignore=skip)
for part in ('tools', 'tests'):
    shutil.copytree(root / part, cand / part, symlinks=True)
print(cand)
EOF
```

以下檔案只寫到候選根。內容、fixture 與測試呼叫須在同一副本；來源鎖仍指上游。

## 第一批應寫檔案

依新手指南的三段完整 JSON 建立候選根下 `game/external/mods/my_pack/mod_info.json`、`cards/card_heavy_strike.json`、`characters/character_red.json`，保留 `properties`／`patch_data` 包裝。卡為費用 2、15 傷害、起手追加一次、暫不進卡包；不要複製官方範例的 script takeover。

`mod_folder_to_load_data` 的 key 相對於 **game 根**，不是相對 mod_info：`external/mods/my_pack/cards/` 映射 `CardData`／`_id_to_card_data`，`external/mods/my_pack/characters/` 映射 `CharacterData`／`_id_to_character_data`。檔名不取代 object_id；角色補丁須使用既有 `character_red`。

資料夾 key **必須保留結尾 `/`**。FileLoader.load_json 以 `directory_partial_path + filename` 拼接，缺尾斜線會找成 `cardscard_heavy_strike.json`；只檢查資料夾存在或 JSON 可解析抓不到這個錯誤。Board Lab 第一次跑 PackScenario 就因此沒有載入內容；修正資料後重新驗證，不修改 FileLoader 來掩蓋包的路徑契約。啟動前逐項核對「登記 key + 實際檔名」等於預期的安裝路徑。

修改候選 `game/external/mod_list.json`：保留 `external/` 與既有項目，在 `properties.mod_load_data` 新增 `"external/mods/my_pack/": {"enabled": true, "load_priority": 10}`。priority 升序載入，避免同 priority 的覆寫碰撞。只建資料夾、只登記 schema、或只放卡 JSON 都不足以啟用 mod。

如需求是獎勵取得，先走 [卡牌設計](../card-design.md) 檢查現有 card_pack_red 的篩選；符合紅色／COMMON／ATTACK 且 `card_appears_in_card_packs=true` 的卡可用既有 pack，不必一律新建 pack。以下 probe 刻意限定起手版，改規格時同步改斷言。

## 接著寫 probe 與執行

測試 helper、接入 Smoke 的位置、實際命令與交付範圍見 [probe 與命令](bootstrap-probe.md)。
