;
; Settings GUI for Numpad MacroPad
; Provides layer management and per-key action editing.
;

class SettingsGui {
    __New(cfgManager, onChangeCallback, recordCallback) {
        this.cfgManager := cfgManager
        this.onChange := onChangeCallback
        this.onRecord := recordCallback
        this.gui := Gui(, "Numpad MacroPad - Settings")
        this.gui.OnEvent("Close", (*) => this.Hide())
        this.gui.SetFont("s10")
        this.BuildLayout()
    }

    BuildLayout() {
        g := this.gui
        g.AddText("xm ym+10", "Layers:")
        this.layerList := g.AddListBox("xm w200 r5", this.GetLayerNames())
        this.layerList.OnEvent("Change", ObjBindMethod(this, "OnLayerChange"))

        this.btnAdd := g.AddButton("xm w95 yp+90", "Add Layer")
        this.btnAdd.OnEvent("Click", ObjBindMethod(this, "AddLayer"))
        this.btnRemove := g.AddButton("x+10 w95 yp", "Remove Layer")
        this.btnRemove.OnEvent("Click", ObjBindMethod(this, "RemoveLayer"))
        this.btnRename := g.AddButton("xm w200 yp+35", "Rename Layer")
        this.btnRename.OnEvent("Click", ObjBindMethod(this, "RenameLayer"))

        g.AddText("x+30 yp-100", "Key mappings for selected layer:")
        g.AddText("x+0 yp+20 w60", "Key")
        g.AddText("x+60 yp w130", "Button Label")
        g.AddText("x+200 yp w120", "Action Type")
        g.AddText("x+330 yp w170", "Action Value")

        this.dataControls := []
        rowY := g.MarginY + 40
        loop 10 {
            idx := A_Index - 1
            yPos := rowY + (A_Index - 1) * 30
            g.AddText("x+0 yp" (A_Index=1?"":"+30") " w60", "Numpad" idx)
            labelEdit := g.AddEdit("x+0 yp w130", "")
            typeDDL := g.AddDropDownList("x+10 yp-1 w120 Choose1", ["Send Key", "Send Text", "Run Program"])
            valueEdit := g.AddEdit("x+10 yp+1 w170", "")
            recordBtn := g.AddButton("x+10 yp-1 w70", "Record")
            recordBtn.OnEvent("Click", ObjBindMethod(this, "OnRecordClick", A_Index))

            labelEdit.OnEvent("Change", ObjBindMethod(this, "OnRowChange", A_Index))
            typeDDL.OnEvent("Change", ObjBindMethod(this, "OnRowChange", A_Index))
            valueEdit.OnEvent("Change", ObjBindMethod(this, "OnRowChange", A_Index))

            this.dataControls.Push({
                label: labelEdit,
                type: typeDDL,
                value: valueEdit,
                record: recordBtn
            })
        }
    }

    GetLayerNames() {
        names := []
        for layer in this.cfgManager.config.layers
            names.Push(layer.name)
        return names
    }

    Show(selectedIndex := 1) {
        this.layerList.Delete()
        for name in this.GetLayerNames()
            this.layerList.Add(name)
        this.layerList.Value := selectedIndex
        this.PopulateRows(selectedIndex)
        this.gui.Show()
    }

    Hide(*) {
        this.gui.Hide()
    }

    PopulateRows(layerIndex) {
        layer := this.cfgManager.config.layers[layerIndex]
        if !layer
            return
        loop 10 {
            data := layer.actions[A_Index]
            controls := this.dataControls[A_Index]
            controls.label.Value := data.label
            controls.type.Value := data.type
            controls.value.Value := data.value
        }
    }

    OnLayerChange(*) {
        idx := this.layerList.Value
        this.PopulateRows(idx)
    }

    OnRowChange(rowIndex, ctrl, *) {
        layer := this.cfgManager.config.layers[this.layerList.Value]
        row := layer.actions[rowIndex]
        row.label := this.dataControls[rowIndex].label.Value
        row.type := this.dataControls[rowIndex].type.Value
        row.value := this.dataControls[rowIndex].value.Value
        this.onChange()
    }

    OnRecordClick(rowIndex, *) {
        ctrl := this.dataControls[rowIndex].value
        this.onRecord(rowIndex, ctrl)
    }

    AddLayer(*) {
        input := InputBox("Enter layer name", "Add Layer", "Default Layer")
        if input.Result = "OK" {
            layerName := input.Value
            this.cfgManager.config.layers.Push({"name": layerName, "actions": this.cfgManager.BlankActions()})
            this.onChange()
            this.Show(this.cfgManager.config.layers.Length)
        }
    }

    RemoveLayer(*) {
        if this.cfgManager.config.layers.Length = 1 {
            MsgBox("At least one layer is required.")
            return
        }
        idx := this.layerList.Value
        this.cfgManager.config.layers.RemoveAt(idx)
        newIdx := idx > this.cfgManager.config.layers.Length ? this.cfgManager.config.layers.Length : idx
        this.onChange()
        this.Show(newIdx)
    }

    RenameLayer(*) {
        idx := this.layerList.Value
        layer := this.cfgManager.config.layers[idx]
        input := InputBox("Rename layer", "Rename Layer", layer.name)
        if input.Result = "OK" {
            layer.name := input.Value
            this.onChange()
            this.Show(idx)
        }
    }
}
