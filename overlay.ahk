;
; Overlay display for Numpad MacroPad
;

class Overlay {
    __New() {
        this.holdGui := this.CreateOverlayGui()
        this.flashGui := this.CreateOverlayGui()
        this.hideTimer := 0
    }

    CreateOverlayGui() {
        gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
        gui.BackColor := "222222"
        gui.SetFont("s12 cFFFFFF", "Segoe UI")
        gui.Opacity := 220
        return gui
    }

    UpdateData(layer) {
        this.currentLayer := layer
    }

    ShowHold(layer) {
        this.UpdateData(layer)
        this.holdGui.Destroy()
        this.holdGui := this.CreateOverlayGui()
        g := this.holdGui
        g.MarginX := 12
        g.MarginY := 12
        g.AddText("w300 Center s14 Bold", layer.name)
        g.AddText("w300 cAAAAAA", "Press Numpad key")
        for idx, action in layer.actions {
            row := g.AddText("w300", "" idx-1 " — " action.label)
        }
        g.Show("AutoSize Center")
    }

    HideHold() {
        this.holdGui.Hide()
    }

    ShowFlash(text) {
        this.flashGui.Destroy()
        this.flashGui := this.CreateOverlayGui()
        g := this.flashGui
        g.AddText("w220 Center s14 Bold", text)
        g.Show("AutoSize Center")
        SetTimer(ObjBindMethod(this, "HideFlash"), -700)
    }

    HideFlash(*) {
        this.flashGui.Hide()
    }
}
