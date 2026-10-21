# RNG 與資料契約

[機制入口](../mechanics.md)｜[驗收分流](../validation.md)｜[擴充契約](../../../../analysis/slay-the-robot/architecture/02_extension_points.md)

**何時用**：機制改動會新增或改變隨機抽樣、保存 RNG 狀態、新增可存欄位，或修改 `patch_dictionary()` 等 JSON patch 策略。

**何時不用**：只是沿用既有 Random helper 的內容資料，回 [content](../content.md)；所有權、快取與清理問題走 [資源生命週期](../resource-lifecycle.md)。

## 隨機序列

使用 `PlayerData.get_player_rng(name)` 及既有的 Random helper，確認命名流是否會影響其他隨機序列；不要悄悄換用全域亂數。涉及隨機結果時，用固定 seed 與相同操作序列重跑；若 RNG 狀態會保存，再做保存／載入後的後續序列比較。說明新增抽樣是否會改變同 seed 的既有結果。

## 序列化與 patch 策略

序列化須分別檢查普通值、typed collections、遞迴 embedded objects 的分支；新增欄位要核對預設值與舊檔缺欄位的情況。`patch_dictionary()` 支援 `merge_keep`、`merge_overwrite`；普通 Dictionary JSON 分支的本地修復、淺合併語意與固定案例見 [validation 的 Dictionary 回歸契約](../validation.md#dictionary-回歸契約)，Smoke 也有斷言。recursive/native 分支不共用相同策略，Dictionary 沒有 append。

修改這類契約時，保留舊 key、新 key 與重複 key 策略的 regression，經公開 JSON patch 入口驗證，不只測 helper；依影響補嵌套與存讀案例。未知策略目前走 overwrite；是否改為錯誤屬行為決策，要連同所有引用一起處理。修復後同步所有現行指引；歷史報告保留當時結果，並連到新證據。
