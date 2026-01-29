;
; AutoHotkey Version: 2.x
; Language:       English
; Platform:       Windows
; Author:         Michael Soza (converted to v2)
; Based upon the 'Mouser' AutoHotkey script by Adam Pash <adam.pash@gmail.com>
; Based upon DNC from Petr 'Vorkronor' Stedry (petr.stedry@gmail.com)

#SingleInstance Force
InstallKeybdHook
SetKeyDelay -1
SetWinDelay 0

; Set DPI awareness for accurate coordinates on high DPI displays
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; All configuration is in dnc.ini

iniFile := "dnc.ini"
LoadConfigurationFile()
CoordMode "Mouse", "Screen"

MonitorGetWorkArea(MonitorGetPrimary(), &resLeft, &resTop, &resRight, &resBottom)
MAX_DEPTH := calculateMaxDepth(resBottom)

depth := 0
BackAll := []
drawing := false
gridGuis := []

GetMonitorMouse()
{
    MouseGetPos(&x, &y)
    monitorCount := MonitorGetCount()
    
    Loop monitorCount
    {
        MonitorGet(A_Index, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
        
        if (x >= MonitorLeft && x <= MonitorRight)
        {
            return A_Index
        }
    }
    return 1
}

resetSharedState()
{
    global depth, BackAll, gridGuis
    depth := 0
    BackAll := []
    if (gridGuis.Length > 0)
        CleanUpGui()
}

setupInitialBox()
{
    currentMonitor := GetMonitorMouse()
    MonitorGet(currentMonitor, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
    bD := Map()
    bD["sectorTopX"] := MonitorLeft
    bD["sectorTopY"] := MonitorTop
    bD["sectorWidth"] := (MonitorRight - MonitorLeft)
    bD["sectorHeight"] := (MonitorBottom - MonitorTop)
    
    MouseGetPos(&currentMouseX, &currentMouseY)
    bD["newX"] := currentMouseX
    bD["newY"] := currentMouseY
    return bD
}

setupInitialBoxLeft()
{
    currentMonitor := 1
    MonitorGet(currentMonitor, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
    bD := Map()
    bD["sectorTopX"] := MonitorLeft
    bD["sectorTopY"] := MonitorTop
    bD["sectorWidth"] := (MonitorRight - MonitorLeft)
    bD["sectorHeight"] := (MonitorBottom - MonitorTop)
    
    MouseGetPos(&currentMouseX, &currentMouseY)
    bD["newX"] := currentMouseX
    bD["newY"] := currentMouseY
    return bD
}

setupInitialBoxRight()
{
    currentMonitor := 2
    MonitorGet(currentMonitor, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
    bD := Map()
    bD["sectorTopX"] := MonitorLeft
    bD["sectorTopY"] := MonitorTop
    bD["sectorWidth"] := (MonitorRight - MonitorLeft)
    bD["sectorHeight"] := (MonitorBottom - MonitorTop)
    
    MouseGetPos(&currentMouseX, &currentMouseY)
    bD["newX"] := currentMouseX
    bD["newY"] := currentMouseY
    return bD
}

setupInitialBoxMonitor(monitorNum)
{
    MonitorGet(monitorNum, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
    bD := Map()
    bD["sectorTopX"] := MonitorLeft
    bD["sectorTopY"] := MonitorTop
    bD["sectorWidth"] := (MonitorRight - MonitorLeft)
    bD["sectorHeight"] := (MonitorBottom - MonitorTop)
    
    ; Set initial position to center of monitor
    bD["newX"] := MonitorLeft + Floor(bD["sectorWidth"] / 2)
    bD["newY"] := MonitorTop + Floor(bD["sectorHeight"] / 2)
    return bD
}

main(currentBox, userInput)
{
    global depth, MAX_DEPTH, BackAll
    
    if (depth >= MAX_DEPTH)
    {
        CleanUpGui()
        return currentBox
    }
    
    if (userInput ~= "^[xcvsdfwer]$")
    {
        currentBox := computeNewBox(currentBox, userInput)
        moveMouseToCellCenter(currentBox)
        DrawGrid(currentBox)
        
        BackAll.Push(currentBox)
        depth := depth + 1
    }
    else
    {
        if (userInput = "j")
            ClickLeft()
        
        if (userInput = "l")
            ClickRight()
        
        if (userInput = "k")
            ClickDouble()
        
        if (userInput = "Escape")
            CleanUpGui()
        
        if (userInput = "Space")
        {
            if (depth > 0)
            {
                currentBox := GoBack(BackAll)
                depth := depth - 1
            }
        }
    }
    return currentBox
}

moveMouseToCellCenter(currentBox)
{
    xpos := currentBox["newX"]
    ypos := currentBox["newY"]
    MouseMove xpos, ypos, 0
}

computeNewBox(currentBox, selection)
{
    newBox := Map()
    for key, value in currentBox
        newBox[key] := value
    
    ; Divide the current sector into thirds
    newWidth := Floor(newBox["sectorWidth"] / 3)
    newHeight := Floor(newBox["sectorHeight"] / 3)
    
    ; Start with the top-left position of current sector
    newTopX := newBox["sectorTopX"]
    newTopY := newBox["sectorTopY"]
    
    ; Adjust X position based on column (left, center, right)
    if (selection ~= "[cde]")  ; middle column
        newTopX := newTopX + newWidth
    if (selection ~= "[vfr]")  ; right column
        newTopX := newTopX + (2 * newWidth)
    
    ; Adjust Y position based on row (top, middle, bottom)
    if (selection ~= "[sdf]")  ; middle row
        newTopY := newTopY + newHeight
    if (selection ~= "[xcv]")  ; bottom row
        newTopY := newTopY + (2 * newHeight)
    
    ; Set the new sector boundaries
    newBox["sectorTopX"] := newTopX
    newBox["sectorTopY"] := newTopY
    newBox["sectorWidth"] := newWidth
    newBox["sectorHeight"] := newHeight
    
    ; Calculate center of the NEW sector
    newBox["newX"] := newTopX + Floor(newWidth / 2)
    newBox["newY"] := newTopY + Floor(newHeight / 2)
    
    return newBox
}

calculateMaxDepth(screenSize)
{
    tmpHeight := screenSize
    
    Loop
    {
        tmpHeight := tmpHeight / 3
        
        if (tmpHeight <= 3)
        {
            return A_Index
        }
    }
}

GoBack(history)
{
    history.Pop()
    BackOne := history[history.Length]
    
    moveMouseToCellCenter(BackOne)
    DrawGrid(BackOne)
    return BackOne
}

DrawGrid(boxDefinition)
{
    global drawing, color, transparency
    CleanUpGui()  ; Clear previous grid before drawing new one
    
    drawing := true
    
    bD := Map()
    for key, value in boxDefinition
        bD[key] := value
    
    drawRect(bD["sectorTopX"], bD["sectorTopY"], bD["sectorWidth"], 1, 1)
    drawRect(bD["sectorTopX"] + bD["sectorWidth"] - 1, bD["sectorTopY"], 1, bD["sectorHeight"], 2)
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + bD["sectorHeight"] - 1, bD["sectorWidth"], 1, 3)
    drawRect(bD["sectorTopX"], bD["sectorTopY"], 1, bD["sectorHeight"], 4)
    
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + Floor(bD["sectorHeight"] / 3), bD["sectorWidth"], 1, 5)
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + Ceil(2 * (bD["sectorHeight"] / 3)), bD["sectorWidth"], 1, 6)
    
    drawRect(bD["sectorTopX"] + Floor(bD["sectorWidth"] / 3), bD["sectorTopY"], 1, bD["sectorHeight"], 7)
    drawRect(bD["sectorTopX"] + Ceil(2 * (bD["sectorWidth"] / 3)), bD["sectorTopY"], 1, bD["sectorHeight"], 8)
    
    drawing := false
}

drawRect(x, y, width, height, winNo)
{
    global color, transparency, gridGuis
    gridGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Grid" . winNo)
    gridGui.BackColor := color
    WinSetTransColor("000000 " . transparency, gridGui)
    gridGui.Show("x" . x . " y" . y . " w" . width . " h" . height . " NoActivate")
    gridGuis.Push(gridGui)
}

CleanUpGui()
{
    global drawing, BackAll, gridGuis
    while drawing
    {
        Sleep 50
    }
    
    for gui in gridGuis
    {
        try
            gui.Destroy()
    }
    gridGuis := []
}

Quit()
{
    CleanUpGui()
    ExitApp
}

ClickLeft()
{
    CleanUpGui()
    Click
}

ClickRight()
{
    CleanUpGui()
    Click "Right"
}

ClickDouble()
{
    CleanUpGui()
    Click 2
}

LoadConfigurationFile()
{
    global iniFile, color, transparency, MONITOR_LAYOUT
    
    if !FileExist(iniFile)
    {
        IniWrite("PgDn", iniFile, "Settings", "hotkey_select_monitor")
        IniWrite("PgUp", iniFile, "Settings", "hotkey_current_monitor")
        IniWrite("1,4,2,3", iniFile, "Settings", "monitor_layout")
        IniWrite("00FF00", iniFile, "Settings", "color")
        IniWrite("70", iniFile, "Settings", "transparency")
    }
    
    global HOTKEY_SELECT_MONITOR := IniRead(iniFile, "Settings", "hotkey_select_monitor", "PgDn")
    global HOTKEY_CURRENT_MONITOR := IniRead(iniFile, "Settings", "hotkey_current_monitor", "PgUp")
    
    ; Parse monitor layout from comma-separated string
    layoutStr := IniRead(iniFile, "Settings", "monitor_layout", "1,4,2,3")
    MONITOR_LAYOUT := []
    Loop Parse, layoutStr, ","
    {
        MONITOR_LAYOUT.Push(Integer(Trim(A_LoopField)))
    }
    
    color := IniRead(iniFile, "Settings", "color", "00FF00")
    transparency := IniRead(iniFile, "Settings", "transparency", "70")
}

; Setup dynamic hotkeys based on configuration
SetupHotkeys()
{
    global HOTKEY_CURRENT_MONITOR, HOTKEY_SELECT_MONITOR
    
    ; Hotkey for current monitor
    Hotkey(HOTKEY_CURRENT_MONITOR, ActivateCurrentMonitor)
    
    ; Hotkey for monitor selection
    Hotkey(HOTKEY_SELECT_MONITOR, ActivateMonitorSelection)
}

ActivateCurrentMonitor(*)
{
    BlockInput true
    resetSharedState()
    global BackAll
    currentMonitor := GetMonitorMouse()
    currentBox := setupInitialBoxMonitor(currentMonitor)
    moveMouseToCellCenter(currentBox)
    DrawGrid(currentBox)
    BackAll.Push(currentBox)
    MainLoop(currentBox)
    BlockInput false
}

ActivateMonitorSelection(*)
{
    BlockInput true
    global MONITOR_LAYOUT, BackAll
    
    ; Show selection prompt
    ToolTip "Select Monitor (Left to Right):`nA = 1st | S = 2nd`nD = 3rd | F = 4th`nEsc = Cancel"
    
    ; Wait for monitor selection
    ih := InputHook("L1", "{Escape}")
    ih.Start()
    ih.Wait()
    
    physicalPos := 0
    
    if (ih.Input = "a")
        physicalPos := 1
    else if (ih.Input = "s")
        physicalPos := 2
    else if (ih.Input = "d")
        physicalPos := 3
    else if (ih.Input = "f")
        physicalPos := 4
    
    ToolTip  ; Clear tooltip
    
    if (physicalPos > 0 && physicalPos <= MONITOR_LAYOUT.Length)
    {
        monitorNum := MONITOR_LAYOUT[physicalPos]
        resetSharedState()
        currentBox := setupInitialBoxMonitor(monitorNum)
        moveMouseToCellCenter(currentBox)
        DrawGrid(currentBox)
        BackAll.Push(currentBox)
        MainLoop(currentBox)
    }
    
    BlockInput false
}

; Initialize hotkeys
SetupHotkeys()

MainLoop(currentBox)
{
    Loop
    {
        ih := InputHook("L1", "{Escape}{Space}")
        ih.Start()
        ih.Wait()
        
        userInput := ih.Input
        
        if (ih.EndKey = "Space")
            userInput := "Space"
        
        if (ih.EndKey = "Escape")
            userInput := "Escape"
        
        currentBox := main(currentBox, userInput)
        
        if (userInput ~= "^[jkl]$" || userInput = "Escape")
            break
    }
}
