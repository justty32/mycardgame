# 每場棋盤資料格式 v1

[整合實證](../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)｜[資料責任](encounter-contracts.md)｜[開始與清理](encounter-lifecycle.md)

C 的外部輸入使用 EncounterData 的 `encounter_board_setup`，沿既有 SerializableData 的 `properties` 載入／匯出。欄位局部保留原始 Variant，使 JSON scalar／null 不會先被 typed Dictionary 賦值丟失；不修改所有資料類的序列化器。

## 省略、空與錯誤

省略欄位或真正空物件 `{}` 使用舊格式。非空物件必須有版本 `1` 與 `boards` 陣列；`{"version":1,"boards":[]}` 是合法 0，場景真正不掛棋盤模組。非空缺版本、缺盤集合、scalar、null 或其他版本均為錯誤，不當成 0 或 legacy。

明確 0 只接受版本與空盤集合，不容許殘留部署或呈現欄位，避免忽略矛盾的位置資料。

新格式不能同時帶非預設舊棋盤覆寫：`encounter_board_mode` 必須維持 `-1`、`encounter_board_size` 維持 `[0,0]`，舊 `encounter_boards`、部署／生成／障礙／初始場域清單維持空。正常匯出會包含這些預設欄位，不能僅因鍵存在便拒絕。波次與材質欄位仍可共用；舊空 `encounter_boards={}` 絕不代表 0。

## 正盤輸入

以下是最小單盤內容示例，ID 與位置是內容指定值，不是框架預設：

```json
{
  "version": 1,
  "boards": [{"id": "arena", "size": [7, 5]}],
  "deployment": {
    "policy": "explicit_positions",
    "hero": {"board_id": "arena", "cell": [3, 4]},
    "spawn": {"board_id": "arena", "cell": [3, 0]}
  },
  "presentation": {
    "slots": [{"board_id": "arena", "rect": [360, 170, 460, 280]}]
  }
}
```

`boards` 可有任意數目的唯一非空 ID，沒有把測試盤數當上限。每盤明確給 `size`，沿既有每盤大小安全限制；可選 `blocked_cells`、`deploy_cells`、`spawn_zone_cells`、`initial_fields` 使用既有格座標／場域資料形狀。盤內格與引用須有效，重複 ID、未知目的盤及錯誤尺寸拒絕整份設定。

部署是獨立政策區塊。當前支援 `explicit_positions`：它要求既有主角 admission 的明確起點，`spawn` 可選作生成位置缺省；波次 entry 可明確覆寫位置，合成後仍不完整就拒絕。政策只產位置要求，可放性與最近可放格由幾何處理；沒有合法 footprint 時回部署失敗。這不將「主角必上盤」寫入幾何定義，也不替未來其他政策決定隊友、home 或盤外單位規則；未知政策需明確拒絕。

呈現以 `presentation.slots` 為每個 ID 提供有限數值、正尺寸的矩形，必須恰好覆蓋定義集合。矩形與排序不改世界 ID、anchor 或 faction；新格式不隱式套單／雙槽。內容可指定不同矩形，尚未定產品的自動縮放、捲動或分頁方案。

## 能力與錯誤

PreparedEncounter 先驗核心 envelope／波次，棋盤可用時再透過路徑載入模組的純正規化器。明確正盤遇場景關閉、規則關閉或模組缺檔回 `board_module_unavailable`，並分別附 `scene_disabled`、`rules_disabled`、`module_missing` 原因；舊格式仍保留原 ordinary-combat fallback。合法 0 不需要棋盤能力。

命名 Encounter 不存在回 `missing_encounter`，不合成另一場；格式錯誤回 `invalid_board_setup`，新舊衝突回 `conflicting_board_formats`。部署、場域、位置與呈現錯誤由各 owner 回代碼／細節，不合併成空集合。失敗時尚未發布成功開始通知，不能啟動首波或 CTB；驗證證據依遷移計畫收錄。
