# UI tooltip 與卡面延後刷新

[UI 入口](../ui.md)｜[互動與狀態](interaction-states.md)｜[元件與版面](components-layout.md)｜[專項驗證](verification.md)

**何時用**：改 tooltip 的顯示、隱藏、位置或關鍵字展開；改卡面文字／費用預覽的刷新時機；新增 focus 提示。

**何時不用**：tooltip 的外觀與 theme 接 [元件與版面](components-layout.md)；出牌與選目標接 [互動與狀態](interaction-states.md)。

## Done when

- 任務 spec 記有觸發來源（hover／focus）、隱藏與清理時點、刷新策略。
- [專項驗證](verification.md) 的 tooltip 斷言回傳預期結果；文件 lint 通過（見 [testing](../../testing.md)）。

## 流程

### Tooltip 的接線

Root 的節點實名是 `Tooptips`（原拼字），腳本為 [Tooltips.gd](../../../../game/scripts/ui/Tooltips.gd)，HandManager.tooltip 指向它。Card hover 啟動 0.5 秒 KeywordTimer，timeout 呼叫 display_card_keywords；mouse_exited 停 timer、hide_tooltip 並取消 hover。HUD tooltip 由 component_tooltip_data 連 mouse_entered／exited。新增 focus 提示需另外接 focus_entered／exited，不能期待 hover 自動涵蓋鍵盤。

KeywordContainer 依 KeywordData 遞迴建立 KeywordTooltip；hide_tooltip 會 queue_free 子項並隱藏容器。卡牌左右放置使用 DisplayServer.window_get_size 與固定 200 邊界；這不是 viewport 邊界保證，也未限制底部溢出。tooltip 裝飾層目前 mouse_filter=IGNORE；改遮罩時避免吞掉卡牌命中。切 modal／離樹時要取消 timer 和清 tooltip，不能只等待 mouse_exited。

### 延後刷新與預覽副作用

update_card_display 以 `_card_is_rerendering` 合併到下一個 process_frame；同 frame 後來的目標更新可能直接 return。名稱／描述之後還有 RichLabelAutoSizer 的延後處理，KeywordTooltip 的 fit_content 也是 set_deferred。fixture 要等狀態完成再取字串／尺寸；若改刷新策略，補上快速換目標與等待中移除的案例。

預覽會生成 Action／Interceptor；不得改能量、牌堆、具名 RNG，也不能留下持有鏈。KeywordContainer 目前直接取 card_keyword_object_ids 再追加推導出的關鍵字，所以不能假設 tooltip 完全不改 CardData；改這段時要專測原資料與重複展開。

## 交接

tooltip 與預覽的副作用斷言交 [專項驗證](verification.md)；字型、視覺遮擋與真實 hover／focus 仍需另一層證據。
