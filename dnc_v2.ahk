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
SetWinDelay -1
SetMouseDelay -1
Thread "Interrupt", 0

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
gridGuis := []
gridSession := 0
activeMonitor := 0
activeWindow := 0
lastClick := 0

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

GetMonitorActiveWindow()
{
    try
    {
        WinGetPos(&winX, &winY, &winWidth, &winHeight, "A")
        ; Use center of window to determine monitor
        centerX := winX + Floor(winWidth / 2)
        centerY := winY + Floor(winHeight / 2)
        
        monitorCount := MonitorGetCount()
        
        Loop monitorCount
        {
            MonitorGet(A_Index, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
            
            if (centerX >= MonitorLeft && centerX <= MonitorRight && 
                centerY >= MonitorTop && centerY <= MonitorBottom)
            {
                return A_Index
            }
        }
    }
    return 1  ; Default to primary monitor if window detection fails
}

resetSharedState()
{
    global depth, BackAll
    depth := 0
    BackAll := []
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

setupInitialBoxWindow(windowId, &monitorNum)
{
    WinGetPos(&winX, &winY, &winWidth, &winHeight, windowId)
    largestArea := 0
    monitorNum := 0
    Loop MonitorGetCount()
    {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        visibleLeft := Max(winX, left)
        visibleTop := Max(winY, top)
        visibleWidth := Max(0, Min(winX + winWidth, right) - visibleLeft)
        visibleHeight := Max(0, Min(winY + winHeight, bottom) - visibleTop)
        area := visibleWidth * visibleHeight
        if (area > largestArea)
        {
            largestArea := area
            monitorNum := A_Index
            box := Map("sectorTopX", visibleLeft, "sectorTopY", visibleTop,
                "sectorWidth", visibleWidth, "sectorHeight", visibleHeight,
                "newX", visibleLeft + Floor(visibleWidth / 2),
                "newY", visibleTop + Floor(visibleHeight / 2))
        }
    }
    if (monitorNum = 0)
        throw Error("The active window has no visible area on a monitor.")
    return box
}

main(currentBox, userInput)
{
    global depth, MAX_DEPTH, BackAll
    
    if (userInput ~= "^[xcvsdfwer]$")
    {
        if (depth >= MAX_DEPTH || currentBox["sectorWidth"] < 3
            || currentBox["sectorHeight"] < 3)
            return currentBox

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
    bD := boxDefinition
    
    drawRect(bD["sectorTopX"], bD["sectorTopY"], bD["sectorWidth"], 1, 1)
    drawRect(bD["sectorTopX"] + bD["sectorWidth"] - 1, bD["sectorTopY"], 1, bD["sectorHeight"], 2)
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + bD["sectorHeight"] - 1, bD["sectorWidth"], 1, 3)
    drawRect(bD["sectorTopX"], bD["sectorTopY"], 1, bD["sectorHeight"], 4)
    
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + Floor(bD["sectorHeight"] / 3), bD["sectorWidth"], 1, 5)
    drawRect(bD["sectorTopX"], bD["sectorTopY"] + Ceil(2 * (bD["sectorHeight"] / 3)), bD["sectorWidth"], 1, 6)
    
    drawRect(bD["sectorTopX"] + Floor(bD["sectorWidth"] / 3), bD["sectorTopY"], 1, bD["sectorHeight"], 7)
    drawRect(bD["sectorTopX"] + Ceil(2 * (bD["sectorWidth"] / 3)), bD["sectorTopY"], 1, bD["sectorHeight"], 8)
    
}

PrepareGridGuis()
{
    global color, transparency, gridGuis
    Loop 8
    {
        gridGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Grid" . A_Index)
        gridGui.BackColor := color
        WinSetTransColor("000000 " . transparency, gridGui)
        gridGuis.Push(gridGui)
    }
}

drawRect(x, y, width, height, winNo)
{
    global gridGuis
    gridGui := gridGuis[winNo]
    gridGui.Show("x" . x . " y" . y . " w" . width . " h" . height . " NoActivate")
}

CleanUpGui()
{
    global gridGuis
    for gui in gridGuis
        gui.Hide()
}

Quit()
{
    CleanUpGui()
    ExitApp
}

ClickLeft()
{
    CleanUpGui()
    RememberClickedCell()
    Click
}

ClickRight()
{
    CleanUpGui()
    RememberClickedCell()
    Click "Right"
}

ClickDouble()
{
    CleanUpGui()
    RememberClickedCell()
    Click 2
}

RememberClickedCell()
{
    global activeMonitor, activeWindow, BackAll, lastClick
    MouseGetPos(&x, &y)
    lastClick := Map("monitor", activeMonitor, "window", activeWindow, "x", x, "y", y,
        "history", BackAll.Clone())
}

StartMonitorGrid(monitorNum)
{
    return StartGrid(setupInitialBoxMonitor(monitorNum), monitorNum)
}

StartGrid(currentBox, monitorNum, windowId := 0)
{
    global activeMonitor, activeWindow, BackAll, depth, lastClick
    MouseGetPos(&x, &y)
    resetSharedState()
    activeMonitor := monitorNum
    activeWindow := windowId
    BackAll.Push(currentBox)

    if (IsObject(lastClick) && lastClick["monitor"] = monitorNum
        && lastClick["window"] = windowId
        && lastClick["x"] = x && lastClick["y"] = y)
    {
        savedRoot := lastClick["history"][1]
        ; Changed monitor or window bounds invalidate saved cell coordinates.
        if (savedRoot["sectorTopX"] = currentBox["sectorTopX"]
            && savedRoot["sectorTopY"] = currentBox["sectorTopY"]
            && savedRoot["sectorWidth"] = currentBox["sectorWidth"]
            && savedRoot["sectorHeight"] = currentBox["sectorHeight"])
        {
            BackAll := lastClick["history"].Clone()
            depth := BackAll.Length - 1
            currentBox := BackAll[BackAll.Length]
        }
    }

    moveMouseToCellCenter(currentBox)
    DrawGrid(currentBox)
    return currentBox
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
    global HOTKEY_CURRENT_WINDOW := IniRead(iniFile, "Settings", "hotkey_current_window", "")
    if (HOTKEY_CURRENT_WINDOW = "")
    {
        HOTKEY_CURRENT_WINDOW := "CapsLock"
        IniWrite(HOTKEY_CURRENT_WINDOW, iniFile, "Settings", "hotkey_current_window")
    }
    
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
    global HOTKEY_CURRENT_MONITOR, HOTKEY_SELECT_MONITOR, HOTKEY_CURRENT_WINDOW
    
    ; Hotkey for current monitor
    Hotkey(HOTKEY_CURRENT_MONITOR, ActivateCurrentMonitor)
    
    ; Hotkey for monitor selection
    Hotkey(HOTKEY_SELECT_MONITOR, ActivateMonitorSelection)
    Hotkey(HOTKEY_CURRENT_WINDOW, ActivateCurrentWindow)
}

ActivateCurrentWindow(*)
{
    ActivateGrid("window")
}

ActivateCurrentMonitor(*)
{
    ActivateGrid("monitor")
}

ActivateMonitorSelection(*)
{
    ActivateGrid("selection")
}

ActivateGrid(target)
{
    global gridSession, MONITOR_LAYOUT
    Critical
    if IsObject(gridSession)
    {
        Critical "Off"
        return
    }

    try
        gridSession := BeginGridInput()
    finally
        Critical "Off"
    try
    {
        if (target = "window")
        {
            windowId := WinExist("A")
            if (!windowId || WinGetMinMax(windowId) = -1)
                throw Error("There is no visible active window to draw a grid in.")
            currentBox := setupInitialBoxWindow(windowId, &monitorNum)
            currentBox := StartGrid(currentBox, monitorNum, windowId)
        }
        else
        {
            if (target = "selection")
            {
                ToolTip "Select Monitor (Left to Right):`nA = 1st | S = 2nd`nD = 3rd | F = 4th`nEsc = Cancel"
                key := ReadGridKey(gridSession)
                ToolTip
                positions := Map("a", 1, "s", 2, "d", 3, "f", 4)
                if (!positions.Has(key) || positions[key] > MONITOR_LAYOUT.Length)
                    return
                monitorNum := MONITOR_LAYOUT[positions[key]]
            }
            else
                monitorNum := GetMonitorActiveWindow()
            currentBox := StartMonitorGrid(monitorNum)
        }
        MainLoop(currentBox)
    }
    finally
    {
        try
        {
            ToolTip
            CleanUpGui()
        }
        finally
        {
            try
                EndGridInput(gridSession)
            finally
                gridSession := 0
        }
    }
}

BeginGridInput()
{
    ih := InputHook("L0")
    session := Map("hook", ih, "queue", [], "next", 1, "held", Map(), "closing", false)
    ih.KeyOpt("{All}", "NS")
    ih.OnKeyDown := QueueGridKey.Bind(session)
    ih.OnKeyUp := ReleaseGridKey.Bind(session)
    ih.Start()
    return session
}

QueueGridKey(session, ih, vk, sc)
{
    Critical
    code := Format("vk{:X}sc{:X}", vk, sc)
    session["held"][code] := true
    if session["closing"]
        return
    key := GetKeyName(code)
    if (StrLen(key) = 1)
        key := StrLower(key)
    session["queue"].Push(key)
}

ReleaseGridKey(session, ih, vk, sc)
{
    Critical
    code := Format("vk{:X}sc{:X}", vk, sc)
    if session["held"].Has(code)
        session["held"].Delete(code)
}

ReadGridKey(session)
{
    while (session["next"] > session["queue"].Length)
        Sleep 1
    key := session["queue"][session["next"]]
    session["next"] += 1
    return key
}

EndGridInput(session)
{
    session["closing"] := true
    ; Keep suppressing repeats and trailing burst keys until captured keys are released.
    Loop
    {
        Sleep -1
        if (session["held"].Count = 0)
            break
        Sleep 1
    }
    session["hook"].Stop()
    session["hook"].OnKeyDown := ""
    session["hook"].OnKeyUp := ""
}

PrepareGridGuis()
SetupHotkeys()

MainLoop(currentBox)
{
    global gridSession
    Loop
    {
        userInput := ReadGridKey(gridSession)
        currentBox := main(currentBox, userInput)
        
        if (userInput ~= "^[jkl]$" || userInput = "Escape")
            break
    }
}
