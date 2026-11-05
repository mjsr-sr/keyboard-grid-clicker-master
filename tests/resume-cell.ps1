param(
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '..\dnc_v2.ahk') -Raw
$functions = @(
    'resetSharedState', 'setupInitialBoxMonitor', 'main',
    'moveMouseToCellCenter', 'computeNewBox', 'GoBack',
    'ClickLeft', 'ClickRight', 'ClickDouble',
    'RememberClickedCell', 'StartMonitorGrid'
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
depth := 0
MAX_DEPTH := 3
BackAll := []
gridGuis := []
activeMonitor := 0
lastClick := 0
mouseX := 100
mouseY := 200
monitorWidth := 1920
clicks := []
drawnBox := 0

try
{
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
    FileAppend("PASS: left/right/double click resume, exact coordinates, monitor/bounds guards, history, Escape, depth limit`n", "*")
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
'@

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("grid-resume-" + [guid]::NewGuid() + ".ahk")
try {
    Set-Content $tempScript ($harness + "`r`n" + ($implementation -join "`r`n")) -Encoding UTF8
    $process = Start-Process -FilePath $AutoHotkey -ArgumentList '/ErrorStdOut', "`"$tempScript`"" -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        throw "AutoHotkey regression tests failed with exit code $($process.ExitCode)"
    }
}
finally {
    Remove-Item -LiteralPath $tempScript
}
