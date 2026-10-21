# mixing — bus、設定、播放池與無聲驗證

[聲音子流程](../audio.md)｜[資源生命週期](../resource-lifecycle.md)｜[測試規則](../../testing.md)

**何時用**：調音量／靜音／bus、併發與回收，或要把聲音接線變成可執行背景驗證。
**何時不用**：音色或循環製作回 sfx／music；未取得播放授權時不做聽音驗收。

## Done when

交付檔有 bus／設定／池的預期與斷言日誌；實際執行命令、隔離位置、driver 或替身證據、完成標記及禁止錯誤檢查結果存在。只有靜態或替身證據時如實標記；只改文件時，文件 lint 通過（見 [testing](../../testing.md)）即可。

## 流程

### 路由、設定與併發

bus layout（只有 Master、Music、Sounds）、四池預設與回收、音量 setter 單位、SettingsMenu 套量／保存與失焦 mute 的現況見 [核實分析](../../../../analysis/slay-the-robot/design/audio.md#播放池與混音) 及其「設定與未驗邊界」「池的額外生命週期風險」兩節。修改時：

新增 UI／Ambient bus 要同時改預設選擇、控制器、設定 schema、缺欄預設及舊設定回讀；override_bus 不存在時可能回落 Master，先斷言 index >= 0 與實際 player.bus，不以有聲音判定路由。

避免 Master 與子 bus 重複乘 master；0 值轉 dB 的無限負值不能用一般等值容差，轉回線性量比對。

冷啟動套量由單一 apply 函式供啟動及設定頁共用，先讀值再套 bus，不靠 populate 的 slider 副作用。驗 0／中間值／1，保存後全新程序冷啟動不開設定頁，確認三值與兩 bus 相符；SaveLoad suite 是 run 存讀，不代表 settings 已驗。

持久手動 mute 要與臨時失焦狀態分開再合成有效值；直接呼叫 notification handler 只證明 handler，不證明 OS 事件抵達。

併發先定連按冷卻、同 cue 最大併發、超限丟新音或替換舊音；實作在哪就測哪，不把混音餘量當池管理。池測試記 available／busy 數量、節點與 tween，驗重播不殘留舊 pitch／fade／暫停狀態，超額節點回收與預建池保留分開。

### 現在可執行的靜態檢查

從專案根查引用與 runner 能力，命令不播放也不啟動引擎：

```powershell
rg -n 'load_audio|MISSING_AUDIO|_cached_audio' game/autoload/FileLoader.gd
rg -n 'generate_location_music_action|generate_sound_action|SoundManager' game/scripts game/autoload/ActionGenerator.gd
rg -n 'SUITE_CHOICES|headless|audio-driver' tools/test_game.py
python -c "import wave,pathlib; p=pathlib.Path('game/external/audio/sounds/slash.wav'); w=wave.open(str(p)); print(p, p.stat().st_size, w.getparams(), w.getnframes()/w.getframerate()); w.close()"
```

wave 只驗 WAV 檔頭；MP3／OGG 需另核實可用離線解析器，不能用副檔名推定編碼。hash 以 `sha256sum` 為主（Windows 用 `Get-FileHash -Algorithm SHA256`），保留採用檔與修改來源的 SHA-256。

### 可接入的最小 loader probe（尚未執行範本）

有實作授權時，在 [bootstrap](../content/bootstrap.md) 的候選副本方式新增 `tests/audio_loader_probe.gd`；以下只載入既有 WAV，不呼叫 SoundManager，也不證明播放／聽感。這個範本與 helper 都尚未建立、也尚未執行。

```gdscript
extends RefCounted

func check_loaded(file_loader: Node) -> Dictionary:
    var path: String = "external/audio/sounds/slash.wav"
    var stream: AudioStream = file_loader.load_audio(path, false, false)
    var result: Dictionary = {}
    result["AUDIO: slash loaded without fallback"] = stream != null and stream != file_loader.MISSING_AUDIO
    if stream == null or stream == file_loader.MISSING_AUDIO:
        return result
    result["AUDIO: slash is WAV"] = stream is AudioStreamWAV
    result["AUDIO: slash is nonempty"] = stream.get_length() > 0.0
    if stream is AudioStreamWAV:
        result["AUDIO: WAV loop disabled"] = stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
    result["AUDIO: repeat path returns cache"] = file_loader.load_audio(path, false, false) == stream
    return result
```

在候選 `tests/framework_smoke.gd` 的 `_run()`，起手牌 ID 迴圈之後、`_check_array_patch()` 之前加：

```gdscript
    var probe: RefCounted = load(get_script().resource_path.get_base_dir().path_join("audio_loader_probe.gd")).new()
    var audio_results: Dictionary = probe.check_loaded(file_loader)
    for label: String in audio_results:
        _check(audio_results[label], label)
```

保留原 tab 縮排及 SMOKE PASS；缺檔負例應另設受控情境，不能讓預期 error 污染正式綠測。helper 須由既有測試呼叫才有覆蓋（見 [UI 驗證](../ui/verification.md#把新增-helper-真正接上)）。正式接入後命令為 `python3 tools/test_game.py --suite Smoke`；候選 runner 與 user:// 隔離照 bootstrap。檢查這五個 `PASS: AUDIO:`、SMOKE PASS、results.json 完成／PASS 與禁止錯誤，不只 exit 0。不要執行不存在的 `--suite Audio`。

### 播放、bus 與池的後續橋接

現有 runner 明列 headless，未顯式 audio driver。執行任何可能播放的 fixture 前，先唯讀查實際引擎與啟動能力，再在獲准的背景程序核實 Dummy driver 名稱／可用性與 AudioServer.get_driver_name()；不能把 headless 當成已取得無聲證據。必要 runner 改動須涵蓋 import 與 test 階段，避免先啟動後才在腳本靜音。

替身策略須在任何觸發前攔截播放出口，記錄呼叫與參數；僅在播放後設音量 0 不是隔離。現框架沒有可直接切換的全域 mock 開關，新增 seam 或候選腳本替換要獨立設計並斷言確實生效。替身可驗事件及切曲參數，不能驗真實 bus、解碼、tween／pool。Dummy 可驗邏輯狀態，也不能證明聽感。

按 sfx／music 在既有 Combat／Smoke 建 helper，針對 settings 增加全新程序階段。記源檔 hash、斷言標籤、日誌及超時，池測試至少包含同 frame 超過預建量、自然完結、手動停止、循環離場及 A→B→A。目前尚無這些音訊專項通過證據。

## 交接

聽感驗收須另有授權：同場景疊加、低／中／高音量、長循環、接縫、爆音、遮蔽、延遲與疲勞。未取得授權前只記未驗，不播放。完成後同步核實分析與驗證選擇；一般未完工程交 agent。
