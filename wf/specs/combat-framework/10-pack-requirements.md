# 題材包要提供什麼（給內容作者）

[README](README.md)

## 7. 題材包要提供什麼（給內容作者）

全部為 JSON（`SerializableData` patch 格式），放在 pack 的對應資料夾，id 帶題材前綴；框架不含任何一筆正式內容。

（表）已抽到 [pack-requirements.json](pack-requirements.json)（13 列，含移動增補的 `fields/` 與各類選填欄位，見 [11-movement-active.md](11-movement-active.md) 起）。欄位：資料夾（SCHEMA）、類別、必填、選填。

內容作者守則：所有 id 加前綴並通過 boundary lint；不要依賴框架範例內容的 id（除非側寫允許）；「每回合」一律改寫成「每次行動」或「每 N 刻」。
