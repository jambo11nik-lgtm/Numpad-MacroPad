#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
#InputLevel 1

#Include gui.ahk
#Include overlay.ahk

;
; Numpad MacroPad main entry point
; - Loads configuration
; - Registers global hotkeys for NumPad
; - Coordinates settings GUI and overlay
; - Manages tray menu
;

class ConfigManager {
    __New(path) {
        this.path := path
        this.config := this.Load()
    }

    Load() {
        try {
            if !FileExist(this.path)
                throw Error("Missing config")
            text := FileRead(this.path, "UTF-8")
            cfg := JSON.Parse(text)
            if !cfg.HasProp("layers") || cfg.layers.Length = 0
                throw Error("Invalid config")
            return cfg
        } catch {
            cfg := this.DefaultConfig()
            this.SaveConfig(cfg)
            return cfg
        }
    }

    Save() {
        this.SaveConfig(this.config)
    }

    SaveConfig(cfg) {
        dir := DirGet(this.path)
        if !DirExist(dir)
            DirCreate(dir)
        FileDelete(this.path)
        FileAppend(JSON.Dump(cfg, "  "), this.path, "UTF-8")
    }

    DefaultConfig() {
        defaultLayer := Map(
            "name", "Default",
            "actions", this.BlankActions([
                {"label": "Copy", "type": "Send Key", "value": "Ctrl+C"},
                {"label": "Paste", "type": "Send Key", "value": "Ctrl+V"},
                {"label": "New", "type": "Send Key", "value": "Ctrl+N"},
                {"label": "Save", "type": "Send Key", "value": "Ctrl+S"},
                {"label": "Undo", "type": "Send Key", "value": "Ctrl+Z"},
                {"label": "Redo", "type": "Send Key", "value": "Ctrl+Y"},
                {"label": "Run", "type": "Send Text", "value": "Hello"},
                {"label": "Browser", "type": "Run Program", "value": "https://example.com"},
                {"label": "Explorer", "type": "Run Program", "value": "explorer.exe"},
                {"label": "Mute", "type": "Send Key", "value": "Volume_Mute"}
            ])
        )
        secondLayer := Map(
            "name", "Media",
            "actions", this.BlankActions([
                {"label": "Play/Pause", "type": "Send Key", "value": "Media_Play_Pause"},
                {"label": "Prev", "type": "Send Key", "value": "Media_Prev"},
                {"label": "Next", "type": "Send Key", "value": "Media_Next"}
            ])
        )
        return {"layers": [defaultLayer, secondLayer]}
    }

    BlankActions(prefill := []) {
        actions := []
        loop 10 {
            idx := A_Index
            if (idx <= prefill.Length) {
                actions.Push(prefill[idx])
            } else {
                actions.Push({"label": "Button " idx-1, "type": "Send Key", "value": ""})
            }
        }
        return actions
    }
}

class MacroPad {
    __New(cfgManager) {
        this.cfg := cfgManager
        this.currentLayerIndex := 1
        this.numbersMode := false
        this.overlay := new Overlay()
        this.settingsGui := new SettingsGui(cfgManager, ObjBindMethod(this, "OnConfigChange"), ObjBindMethod(this, "RequestRecord"))
        this.RegisterTray()
        this.BindHotkeys()
    }

    CurrentLayer() {
        total := this.cfg.config.layers.Length
        if total = 0
            return
        if this.currentLayerIndex > total
            this.currentLayerIndex := total
        if this.currentLayerIndex < 1
            this.currentLayerIndex := 1
        return this.cfg.config.layers[this.currentLayerIndex]
    }

    BindHotkeys() {
        this.hotkeyNames := []
        loop 10 {
            keyName := "*Numpad" (A_Index - 1)
            this.RegisterHotkey(keyName, ObjBindMethod(this, "HandleMacro", A_Index - 1))
        }
        this.RegisterHotkey("*NumpadAdd", ObjBindMethod(this, "NextLayer"))
        this.RegisterHotkey("*NumpadSub", ObjBindMethod(this, "PrevLayer"))
        this.RegisterHotkey("*NumpadDot", ObjBindMethod(this, "ShowHoldOverlay"))
        this.RegisterHotkey("*NumpadDel", ObjBindMethod(this, "ShowHoldOverlay"))
        this.RegisterHotkey("*NumpadDot Up", ObjBindMethod(this, "HideHoldOverlay"))
        this.RegisterHotkey("*NumpadDel Up", ObjBindMethod(this, "HideHoldOverlay"))
    }

    RegisterHotkey(name, callback) {
        Hotkey(name, callback)
        this.hotkeyNames.Push(name)
    }

    SetHotkeysActive(active := true) {
        state := active ? "On" : "Off"
        for name in this.hotkeyNames
            Hotkey(name, state)
    }

    RegisterTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Open Settings", ObjBindMethod(this, "OpenSettings"))
        A_TrayMenu.Add("Numbers Mode", ObjBindMethod(this, "ToggleNumbersMode"))
        A_TrayMenu.Add("Exit", ObjBindMethod(this, "Exit"))
        A_TrayMenu.Default := "Open Settings"
        A_TrayMenu.ClickCount := 1
        TraySetIcon("shell32.dll", 44)
    }

    ToggleNumbersMode(*) {
        this.numbersMode := !this.numbersMode
        this.SetHotkeysActive(!this.numbersMode)
        if this.numbersMode
            A_TrayMenu.Check("Numbers Mode")
        else
            A_TrayMenu.Uncheck("Numbers Mode")
        this.overlay.ShowFlash(this.numbersMode ? "Numbers Mode" : "Macro Mode")
    }

    OpenSettings(*) {
        this.settingsGui.Show(this.currentLayerIndex)
    }

    Exit(*) {
        ExitApp
    }

    OnConfigChange() {
        this.cfg.Save()
        this.overlay.UpdateData(this.CurrentLayer())
    }

    RequestRecord(rowIndex, valueControl) {
        combo := this.CaptureCombination()
        if combo {
            valueControl.Value := combo
            this.SaveRow(rowIndex)
        }
    }

    CaptureCombination() {
        ToolTip("Press the key combination...")
        ih := InputHook("L1")
        ih.Start()
        ih.Wait()
        ToolTip()
        key := ih.EndKey
        if key = "" {
            return ""
        }
        mods := []
        if GetKeyState("Ctrl", "P")
            mods.Push("Ctrl")
        if GetKeyState("Shift", "P")
            mods.Push("Shift")
        if GetKeyState("Alt", "P")
            mods.Push("Alt")
        if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
            mods.Push("Win")
        combo := ""
        for m in mods
            combo .= m "+"
        combo .= key
        return combo
    }

    HandleMacro(number, *) {
        if this.numbersMode {
            Send "{Numpad" number "}"
            return
        }
        layer := this.CurrentLayer()
        action := layer.actions[number + 1]
        this.ExecuteAction(action)
    }

    ExecuteAction(action) {
        type := action.type
        value := action.value
        if (type = "Send Key") {
            sendText := this.BuildSendString(value)
            if sendText != ""
                Send sendText
        } else if (type = "Send Text") {
            SendText value
        } else if (type = "Run Program") {
            try Run value
        }
    }

    BuildSendString(text) {
        if text = ""
            return ""
        parts := StrSplit(text, "+")
        send := ""
        last := parts.Pop()
        for part in parts {
            p := Trim(part)
            if p = "Ctrl" {
                send .= "^"
            } else if p = "Shift" {
                send .= "+"
            } else if p = "Alt" {
                send .= "!"
            } else if p = "Win" {
                send .= "#"
            }
        }
        key := Trim(last)
        if (RegExMatch(key, "^[A-Za-z0-9]$")) {
            send .= StrLower(key)
        } else {
            send .= "{" key "}"
        }
        return send
    }

    NextLayer(*) {
        total := this.cfg.config.layers.Length
        this.currentLayerIndex := (this.currentLayerIndex mod total) + 1
        this.overlay.ShowFlash(this.CurrentLayer().name)
    }

    PrevLayer(*) {
        total := this.cfg.config.layers.Length
        this.currentLayerIndex := this.currentLayerIndex = 1 ? total : this.currentLayerIndex - 1
        this.overlay.ShowFlash(this.CurrentLayer().name)
    }

    ShowHoldOverlay(*) {
        this.overlay.ShowHold(this.CurrentLayer())
    }

    HideHoldOverlay(*) {
        this.overlay.HideHold()
    }

    SaveRow(rowIndex) {
        layer := this.CurrentLayer()
        row := layer.actions[rowIndex]
        if !row
            return
        controls := this.settingsGui.dataControls[rowIndex]
        row.label := controls.label.Value
        row.type := controls.type.Value
        row.value := controls.value.Value
        this.OnConfigChange()
    }
}

configPath := A_ScriptDir "\\config.json"
cfgManager := new ConfigManager(configPath)
macroPad := new MacroPad(cfgManager)
macroPad.overlay.UpdateData(macroPad.CurrentLayer())
macroPad.OpenSettings()

OnExit(ObjBindMethod(cfgManager, "Save"))

return

;
; Helper to get directory portion of path
;
DirGet(path) {
    SplitPath(path, &fn, &dir)
    return dir = "" ? A_ScriptDir : dir
}

;
; Minimal JSON helper (adapted Jxon)
;
class JSON {
    static Parse(str) {
        pos := 1
        return Jxon_Load(&str, pos)
    }

    static Dump(obj, indent:="") {
        return Jxon_Dump(obj, indent)
    }
}

Jxon_Load(&src, ByRef pos := 1) {
    static quot := Chr(34)
    pos := RegExMatch(src, "\S", &m, pos)
    if !pos
        return
    c := m[0]
    if (c = "{") {
        pos++
        obj := Map()
        while true {
            pos := RegExMatch(src, "\S", &m, pos)
            if !pos
                break
            if (m[0] = "}") {
                pos++
                break
            }
            if (m[0] != quot)
                throw Error("Expected string key at position " pos)
            key := Jxon_LoadString(&src, &pos)
            pos := RegExMatch(src, "\S", &m, pos)
            if (m[0] != ":")
                throw Error("Expected ':' after key")
            pos++
            val := Jxon_Load(&src, pos)
            obj[key] := val
            pos := Jxon_Skip(src, pos)
            if SubStr(src, pos, 1) = "}" {
                pos++
                break
            }
            if SubStr(src, pos, 1) = ","
                pos++
        }
        return obj
    } else if (c = "[") {
        pos++
        arr := []
        while true {
            pos := Jxon_Skip(src, pos)
            if SubStr(src, pos, 1) = "]" {
                pos++
                break
            }
            arr.Push(Jxon_Load(&src, pos))
            pos := Jxon_Skip(src, pos)
            if SubStr(src, pos, 1) = "]" {
                pos++
                break
            }
            if SubStr(src, pos, 1) = ","
                pos++
        }
        return arr
    } else if (c = quot) {
        return Jxon_LoadString(&src, &pos)
    } else if RegExMatch(SubStr(src, pos), "^(true|false|null)", &m) {
        pos += StrLen(m[0])
        return m[0] = "true" ? true : m[0] = "false" ? false : ""
    } else {
        if RegExMatch(SubStr(src, pos), "^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", &m) {
            pos += StrLen(m[0])
            return m[0]+0
        }
    }
}

Jxon_LoadString(&src, &pos) {
    pos := pos + 1
    out := ""
    while pos <= StrLen(src) {
        ch := SubStr(src, pos, 1)
        if ch = Chr(34) {
            pos++
            break
        }
        if ch = "\\" {
            pos++
            esc := SubStr(src, pos, 1)
            switch esc {
                case '"': out .= '"'
                case '\\': out .= '\\'
                case '/': out .= '/'
                case 'b': out .= Chr(08)
                case 'f': out .= Chr(12)
                case 'n': out .= "`n"
                case 'r': out .= "`r"
                case 't': out .= "`t"
                case 'u':
                    hex := SubStr(src, pos+1, 4)
                    out .= Chr("0x" hex)
                    pos += 4
            }
            pos++
        } else {
            out .= ch
            pos++
        }
    }
    return out
}

Jxon_Dump(obj, indent:="", level:=0) {
    space := indent ? "`n" . StrRepeat(indent, level+1) : ""
    endspace := indent ? "`n" . StrRepeat(indent, level) : ""
    if IsObject(obj) {
        if obj is Array {
            parts := []
            for item in obj
                parts.Push(Jxon_Dump(item, indent, level+1))
            return "[" . (parts.Length?space . StrJoin("," . space, parts):"") . (parts.Length?endspace:"") . "]"
        } else {
            parts := []
            for k, v in obj
                parts.Push(Chr(34) k Chr(34) ":" (indent?" ":"") . Jxon_Dump(v, indent, level+1))
            return "{" . (parts.Length?space . StrJoin("," . space, parts):"") . (parts.Length?endspace:"") . "}"
        }
    } else if (obj = true || obj = false) {
        return obj ? "true" : "false"
    } else if (IsNumber(obj)) {
        return obj
    }
    return Chr(34) . StrReplace(obj, "\"", "\\\"") . Chr(34)
}

StrJoin(sep, arr) {
    out := ""
    for idx, val in arr
        out .= (idx>1?sep:"") . val
    return out
}

StrRepeat(str, count) {
    out := ""
    loop count
        out .= str
    return out
}

Jxon_Skip(ByRef src, pos) {
    pos := RegExMatch(src, "\S", , pos)
    return pos
}
