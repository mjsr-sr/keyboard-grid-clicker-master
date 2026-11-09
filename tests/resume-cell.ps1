param(
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '..\dnc_v2.ahk') -Raw
$functions = @(
    'resetSharedState', 'setupInitialBoxMonitor', 'main',
    'moveMouseToCellCenter', 'computeNewBox', 'GoBack',
    'ClickLeft', 'ClickRight', 'ClickDouble',
    'RememberClickedCell', 'StartMonitorGrid', 'StartGrid', 'setupInitialBoxWindow',
    'LoadConfigurationFile', 'SetupHotkeys', 'ActivateCurrentWindow',
    'ActivateCurrentMonitor', 'ActivateMonitorSelection', 'ActivateGrid',
    'GetMonitorActiveWindow'
)
$implementation = foreach ($name in $functions) {
    $match = [regex]::Match($source, "(?ms)^$name\([^\r\n]*\)\r?\n\{.*?^\}")
    if (-not $match.Success) {
        throw "Cannot find function $name"
    }
    $match.Value
}

# Run the production navigation functions with deterministic mouse/monitor/UI doubles.
$harness = @'
#Requires AutoHotkey v2.0
#Warn All, StdOut
#Warn LocalSameAsGlobal, Off
depth := 0
MAX_DEPTH := 3
BackAll := []
gridGuis := []
activeMonitor := 0
activeWindow := 0
lastClick := 0
mouseX := 100
mouseY := 200
monitorWidth := 1920
clicks := []
drawnBox := 0
windowX := 100
windowY := 150
windowWidth := 900
windowHeight := 600
windowId := 42
windowState := 0
inputBlocked := false
gridSession := 0
registeredHotkeys := Map()
iniFile := A_ScriptFullPath ".ini"

try
{
    LoadConfigurationFile()
    Assert(HOTKEY_CURRENT_WINDOW = "CapsLock", "New configuration defaults to CapsLock")
    Assert(IniRead(iniFile, "Settings", "hotkey_current_window") = "CapsLock",
        "New setting is persisted")
    IniDelete(iniFile, "Settings", "hotkey_current_window")
    IniWrite("F7", iniFile, "Settings", "hotkey_current_monitor")
    LoadConfigurationFile()
    Assert(HOTKEY_CURRENT_WINDOW = "CapsLock" && HOTKEY_CURRENT_MONITOR = "F7",
        "Existing configuration gains new setting without overwriting custom hotkeys")
    IniWrite("F8", iniFile, "Settings", "hotkey_current_window")
    LoadConfigurationFile()
    SetupHotkeys()
    Assert(registeredHotkeys["F8"].Name = "ActivateCurrentWindow",
        "Configured window hotkey is wired to window activation")
    ActivateCurrentWindow()
    Assert(activeWindow = 42 && drawnBox["sectorWidth"] = 900 && !inputBlocked,
        "Activation draws the window grid and releases input")
    for state in ["missing", "minimized", "offscreen"]
    {
        windowId := state = "missing" ? 0 : 42
        windowState := state = "minimized" ? -1 : 0
        windowX := state = "offscreen" ? 5000 : 100
        rejected := false
        try
            ActivateCurrentWindow()
        catch as err
            rejected := InStr(err.Message, "visible") > 0
        Assert(rejected && !inputBlocked, "Invalid window reports error and releases input: " state)
    }
    windowId := 42
    windowState := 0
    windowX := 100

    for key in ["j", "l", "k"]
    {
        lastClick := 0
        box := StartMonitorGrid(1)
        box := main(box, "e")
        box := main(box, "s")
        clickedBox := box
        main(box, key)
        Assert(clicks[clicks.Length] = (key = "j" ? "Left" : key = "l" ? "Right" : 2),
            "Correct click type dispatched")
        savedX := mouseX
        savedY := mouseY
        box := StartMonitorGrid(1)
        Assert(box = clickedBox && drawnBox = clickedBox && depth = 2,
            "Same monitor and coordinates restore clicked cell and depth")
        Assert(mouseX = savedX && mouseY = savedY, "Resume does not move cursor")
        box := main(box, "Space")
        Assert(depth = 1 && BackAll.Length = 2, "Space restores parent navigation")
        Assert(lastClick["history"].Length = 3, "Undo does not mutate saved history")
        main(box, "Escape")
        mouseX := savedX
        mouseY := savedY
        box := StartMonitorGrid(1)
        Assert(box = clickedBox, "Escape does not overwrite saved click")
        box := main(box, "w")
        main(box, key)
        box := StartMonitorGrid(1)
        Assert(depth = MAX_DEPTH, "Deepest click can be saved and resumed")
        deepestBox := box
        box := main(box, "r")
        Assert(box = deepestBox && depth = MAX_DEPTH, "Depth limit blocks only refinement")
        box := main(box, "Space")
        Assert(depth = MAX_DEPTH - 1, "Undo works at maximum depth")

        mouseX := lastClick["x"] + 1
        mouseY := lastClick["y"]
        box := StartMonitorGrid(1)
        Assert(depth = 0 && BackAll.Length = 1, "One pixel X movement starts fresh")
        mouseX := lastClick["x"]
        mouseY := lastClick["y"] + 1
        box := StartMonitorGrid(1)
        Assert(depth = 0, "One pixel Y movement starts fresh")
        mouseX := lastClick["x"]
        mouseY := lastClick["y"]
        box := StartMonitorGrid(2)
        Assert(depth = 0 && box["sectorTopX"] = monitorWidth,
            "Different target monitor starts fresh")
        mouseX := lastClick["x"]
        mouseY := lastClick["y"]
        monitorWidth := 1600
        box := StartMonitorGrid(1)
        Assert(depth = 0 && box["sectorWidth"] = 1600, "Changed monitor bounds start fresh")
        monitorWidth := 1920
    }
    lastClick := 0
    box := setupInitialBoxWindow(42, &monitorNum)
    Assert(monitorNum = 1 && box["sectorTopX"] = 100 && box["sectorTopY"] = 150
        && box["sectorWidth"] = 900 && box["sectorHeight"] = 600,
        "Window grid uses exact window bounds, not entire monitor")
    box := StartGrid(box, monitorNum, 42)
    box := main(box, "e")
    main(box, "j")
    clickedBox := box
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    Assert(box = clickedBox && depth = 1, "Window cell resumes")
    box := main(box, "Space")
    Assert(depth = 0 && box["sectorWidth"] = 900, "Window undo returns to window root")
    mouseX := lastClick["x"]
    mouseY := lastClick["y"]
    box := StartGrid(setupInitialBoxWindow(43, &monitorNum), monitorNum, 43)
    Assert(depth = 0, "Another window with identical bounds does not resume")
    mouseX := lastClick["x"]
    mouseY := lastClick["y"]
    windowX += 1
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    Assert(depth = 0, "Moved window starts fresh")
    windowX := 100
    mouseX := lastClick["x"]
    mouseY := lastClick["y"]
    windowWidth += 1
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    Assert(depth = 0, "Resized window starts fresh")

    windowX := -100
    windowY := -50
    windowWidth := 600
    windowHeight := 400
    box := setupInitialBoxWindow(42, &monitorNum)
    Assert(box["sectorTopX"] = 0 && box["sectorTopY"] = 0
        && box["sectorWidth"] = 500 && box["sectorHeight"] = 350,
        "Partially offscreen window clips to monitor")
    windowX := 1800
    windowY := 900
    windowWidth := 600
    windowHeight := 400
    box := setupInitialBoxWindow(42, &monitorNum)
    Assert(monitorNum = 2 && box["sectorTopX"] = 1920
        && box["sectorWidth"] = 480 && box["sectorHeight"] = 180,
        "Spanning window clips to largest-overlap monitor including bottom edge")
    windowX := 5000
    rejected := false
    try
        setupInitialBoxWindow(42, &monitorNum)
    catch as err
        rejected := InStr(err.Message, "no visible area") > 0
    Assert(rejected, "Fully offscreen window reports an explicit error")

    windowX := 0
    windowY := 0
    windowWidth := 1920
    windowHeight := 1080
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    box := main(box, "d")
    main(box, "j")
    box := StartMonitorGrid(1)
    Assert(depth = 0, "Monitor does not resume a full-screen window cell")
    box := main(box, "d")
    main(box, "j")
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    Assert(depth = 0, "Full-screen window does not resume a monitor cell")

    windowWidth := 2
    windowHeight := 30
    box := StartGrid(setupInitialBoxWindow(42, &monitorNum), monitorNum, 42)
    box := main(box, "d")
    Assert(depth = 0 && box["sectorWidth"] = 2, "Tiny window cannot produce zero-width cells")
    main(box, "j")
    FileAppend("PASS: monitor/window resume, clipping, identity/bounds guards, history, Escape, clicks, depth and tiny-window limits`n", "*")
}
catch as err
{
    FileAppend("FAIL: " err.Message " (line " err.Line ")`n", "**")
    ExitApp 1
}
ExitApp 0

Assert(condition, message)
{
    if !condition
        throw Error(message)
}
MouseGetPos(&x, &y)
{
    global mouseX, mouseY
    x := mouseX
    y := mouseY
}
MouseMove(x, y, speed)
{
    global mouseX, mouseY
    mouseX := x
    mouseY := y
}
MonitorGet(number, &left, &top, &right, &bottom)
{
    global monitorWidth
    left := (number - 1) * monitorWidth
    top := 0
    right := left + monitorWidth
    bottom := 1080
}
MonitorGetCount()
{
    return 2
}
WinGetPos(&x, &y, &width, &height, windowId)
{
    global windowX, windowY, windowWidth, windowHeight
    x := windowX
    y := windowY
    width := windowWidth
    height := windowHeight
}
DrawGrid(box)
{
    global drawnBox
    drawnBox := box
}
CleanUpGui()
{
}
Click(button := "Left")
{
    global clicks
    clicks.Push(button)
}
Hotkey(key, callback)
{
    global registeredHotkeys
    registeredHotkeys[key] := callback
}
WinExist(title)
{
    global windowId
    return windowId
}
WinGetMinMax(id)
{
    global windowState
    return windowState
}
BeginGridInput()
{
    global inputBlocked
    inputBlocked := true
    return Map()
}
EndGridInput(session)
{
    global inputBlocked
    inputBlocked := false
}
MainLoop(box)
{
}
ReadGridKey(session)
{
    return "Escape"
}
'@

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("grid-resume-" + [guid]::NewGuid() + ".ahk")
try {
    Set-Content $tempScript ($harness + "`r`n" + ($implementation -join "`r`n")) -Encoding UTF8
    $process = Start-Process -FilePath $AutoHotkey -ArgumentList '/ErrorStdOut', "`"$tempScript`"" -PassThru -NoNewWindow
    $null = $process.Handle
    if (-not $process.WaitForExit(15000)) {
        Stop-Process -Id $process.Id
        throw 'Navigation regression tests timed out'
    }
    if ($process.ExitCode -ne 0) {
        throw "AutoHotkey regression tests failed with exit code $($process.ExitCode)"
    }
}
finally {
    Remove-Item -LiteralPath $tempScript
    if (Test-Path -LiteralPath "$tempScript.ini") {
        Remove-Item -LiteralPath "$tempScript.ini"
    }
}
